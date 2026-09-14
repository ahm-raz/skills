# Code Splitting and Lazy Loading

## Summary
Code splitting breaks an application into chunks loaded on demand; lazy loading defers non-critical code, components, images and iframes until they are needed (route visit, viewport entry, interaction, idle). In React + Next.js this means route-level splitting (automatic in the App Router, explicit in a Vite SPA), `React.lazy`/`next/dynamic` for heavy components, dynamic `import()` for libraries used on interaction, and native `loading="lazy"` for media—balanced with prefetching so navigations stay instant.

## Category
Performance

## Subcategories
Route-based splitting, component-level splitting, import-on-interaction, import-on-visibility, prefetching, Suspense boundaries, native lazy loading, chunk strategy

## Problem It Solves
Monolithic bundles force every user to download and execute code for routes and features they never use, inflating LCP (CSR), hydration cost and input delay. Conversely, over-splitting creates request waterfalls and slow interactions. This skill picks split points and loading triggers deliberately.

## When To Use
- Vite SPA entry chunk > ~100–150 KB brotli, or routes bundled together.
- Heavy components not visible at first paint: rich-text editors, charts, maps, video players, modals, admin panels, emoji pickers.
- Libraries used only after an action (PDF export, image cropper, `zxcvbn`, syntax highlighter for user input).
- Long pages with below-the-fold media or embeds.

## When Not To Use
- Small components (< ~5–10 KB): the extra request + Suspense state costs more than it saves.
- Above-the-fold / LCP content: never lazy-load it.
- Code needed within the first interaction on every page (e.g., navigation menu toggle).

## Core Principles
1. **Split by route first, then by heavy, deferred feature.**
2. **Choose a trigger**: navigation, visibility (IntersectionObserver), interaction (click/focus/hover intent), or idle.
3. **Prefetch what's likely next** (links in viewport/hover, next wizard step) so splitting doesn't cost latency.
4. **Every lazy boundary needs a size-stable, accessible fallback** (no CLS, announces loading).
5. **Avoid waterfalls**: start data and code loading in parallel (route loaders, preload on intent).

## Best Practices
- Next.js App Router splits per route segment automatically; your job is keeping client components lean and using `next/dynamic` for heavy, deferred client UI.
- Next.js `<Link>` prefetches routes in the viewport in production; for dynamic routes, a `loading.tsx` makes partial prefetch useful. Use `prefetch={false}` for large link lists (footers, tables) to save bandwidth.
- Vite SPA: lazy route modules (React Router `lazy`, TanStack Router `autoCodeSplitting`) and preload on link hover/focus.
- Import-on-interaction: load the module in the event handler, and warm it on `pointerenter`/`focus` for perceived instant response.
- Use `loading="lazy"` for below-the-fold `<img>`/`<iframe>`; keep the first 1–3 viewport images eager.
- Group rarely changing vendor code into stable chunks (long-term caching), but don't create one giant vendor chunk loaded everywhere.
- Handle chunk load failures after deploys (old HTML referencing removed chunks): retry once, then full reload.

## Implementation Guidance

### Trigger decision table
| Content | Trigger | React/Next tool |
|---|---|---|
| Route/page | Navigation (+ prefetch on viewport/hover) | App Router automatic; Vite: router `lazy` |
| Modal/dialog/drawer content | Interaction (warm on hover/focus) | `React.lazy`/`next/dynamic` + preload function |
| Chart/map/editor below fold | Visibility | `next/dynamic` inside a visibility wrapper |
| Library used by a button (export, crop) | Interaction | `await import('lib')` in handler |
| Chat widget, feedback tool | Idle / interaction facade | Facade + dynamic import / `next/script lazyOnload` |
| Below-fold images/iframes | Browser-native visibility | `loading="lazy"` / `next/image` default |
| Locale data, large JSON | When locale chosen | `import(\`./locales/${lng}.json\`)` |

### Next.js: heavy client widget
```tsx
// app/dashboard/revenue-card.tsx
'use client';
import dynamic from 'next/dynamic';

const RevenueChart = dynamic(() => import('./revenue-chart'), {
  ssr: false, // browser-only lib (canvas); allowed because this file is a Client Component
  loading: () => <div className="h-72 animate-pulse rounded bg-muted" aria-busy="true" aria-label="Loading chart" />,
});

export function RevenueCard({ data }: { data: { month: string; value: number }[] }) {
  return <section aria-labelledby="rev"><h2 id="rev">Revenue</h2><RevenueChart data={data} /></section>;
}
```

### React: lazy with preload-on-intent
```tsx
import { lazy, Suspense, useState } from 'react';

const loadEditor = () => import('./rich-editor');
const RichEditor = lazy(loadEditor);

export function CommentBox() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        onPointerEnter={loadEditor}   // warm the chunk
        onFocus={loadEditor}
        onClick={() => setOpen(true)}
      >Write a comment</button>
      {open && (
        <Suspense fallback={<div style={{ minHeight: 200 }} aria-busy="true">Loading editor…</div>}>
          <RichEditor />
        </Suspense>
      )}
    </>
  );
}
```

### Import on interaction (library)
```tsx
async function exportPdf(rows: Row[]) {
  const { jsPDF } = await import('jspdf');   // separate chunk, fetched on click
  const doc = new jsPDF();
  rows.forEach((r, i) => doc.text(`${r.name}: ${r.total}`, 10, 10 + i * 8));
  doc.save('report.pdf');
}
```

### Lazy on visibility
```tsx
'use client';
import { useEffect, useRef, useState, type ReactNode } from 'react';

export function WhenVisible({ children, fallback, rootMargin = '200px' }:
  { children: ReactNode; fallback: ReactNode; rootMargin?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) { setVisible(true); io.disconnect(); } }, { rootMargin });
    io.observe(el);
    return () => io.disconnect();
  }, [rootMargin]);
  return <div ref={ref}>{visible ? children : fallback}</div>;
}
```

### Vite SPA routes (React Router data/framework-less mode)
```tsx
import { createBrowserRouter } from 'react-router';
export const router = createBrowserRouter([
  { path: '/', lazy: () => import('./routes/home') },
  { path: '/settings', lazy: () => import('./routes/settings') }, // module exports Component, loader
]);
```

### Chunk load error recovery (Vite)
```ts
window.addEventListener('vite:preloadError', (event) => {
  event.preventDefault();
  if (!sessionStorage.getItem('reloaded-after-deploy')) {
    sessionStorage.setItem('reloaded-after-deploy', '1');
    window.location.reload();
  }
});
```

## Recommended Workflow
1. Analyze bundles; list heavy modules and which routes/interactions use them.
2. Mark each as critical (first paint/first interaction) or deferred; choose a trigger per table.
3. Implement splits with size-matched, accessible fallbacks.
4. Add prefetch/warmup for likely-next routes and interactions.
5. Verify in DevTools Network: chunks load on trigger, no waterfalls (code then data then code), no CLS from fallbacks.
6. Measure: entry/first-load JS down; INP for the lazy interaction still < 200 ms on throttled CPU (chunk fetch + parse included).

## Patterns
- **Preload-on-intent** (`pointerenter`/`focus`/`touchstart`).
- **Facade**: static lightweight preview (image + play button) replaces a heavy embed until click ([third-party-script-management](../third-party-script-management/Skill.md)).
- **Route loader + lazy component in parallel** to avoid code→data waterfalls.
- **Suspense boundary per independent region** so one slow chunk doesn't blank the page.
- **PRPL** (Push/Preload critical, Render initial route, Pre-cache/Prefetch remaining, Lazy-load rest).

## Anti-Patterns
- **Lazy-loading the LCP hero or above-the-fold images** → LCP regression. Fix: eager + `fetchPriority="high"`.
- **Splitting tiny components** → request overhead, flashing fallbacks. Fix: split only heavy (> ~10 KB) or rarely used code.
- **Waterfall: lazy component fetches its data in `useEffect` after chunk load**. Fix: start fetch in route loader / server; preload chunk in parallel.
- **`ssr: false` for content that should be indexable/visible early**. Fix: SSR it; use `ssr: false` only for browser-only APIs.
- **Unbounded `<Link>` prefetch on huge lists**. Fix: `prefetch={false}` or hover-based prefetch.
- **No chunk-error handling after deploys** → blank screens. Fix: error boundary + reload strategy; keep old assets available for a while on the CDN.

## Accessibility
- Fallbacks: `aria-busy="true"` on the region and a text alternative; don't steal focus when content arrives.
- When a lazy dialog opens, move focus into it after it renders ([focus-management](../focus-management/Skill.md)).
- Lazy route changes must announce navigation in SPAs ([accessible-spa-routing](../accessible-spa-routing/Skill.md)).

## Responsive Design
- Load desktop-only features (sidebars with charts, hover previews) conditionally by `matchMedia` or container size, not just hidden with CSS.
- `rootMargin` for visibility triggers should be larger on fast desktop scroll and on slow networks (start earlier).

## Performance
- Each chunk costs a request; HTTP/2+ makes many small chunks acceptable but parse still matters.
- `modulepreload` (Vite injects for direct imports) avoids waterfalls for static dependency chains.
- Lazy interaction cost counts toward INP—warm up chunks on intent.

## Security
- Dynamic `import()` paths must be static or from an allowlist; never build import URLs from user input.
- Keep CSP `script-src` compatible with chunk loading (same origin or nonce/`strict-dynamic`) ([content-security-policy](../content-security-policy/Skill.md)).

## Testing
- Playwright: assert a heavy chunk is *not* requested on initial load (`page.on('request')`) and *is* requested after the trigger.
- Test the Suspense fallback and error boundary (simulate chunk 404 with route interception).
- Lighthouse "Reduce unused JavaScript" before/after.

## Tooling
- `React.lazy` / `Suspense` (React 19) — Active.
- `next/dynamic` (App Router: Client Components; `ssr: false` only there) — Active.
- React Router v7 route `lazy`; TanStack Router `autoCodeSplitting` — Active.
- Next.js `<Link prefetch>` — Active.
- Native `loading="lazy"` for img/iframe — Baseline.

## Framework Notes
- **Next.js (App Router)**: route splitting is automatic; Server Components add zero client JS, so "lazy loading" a Server Component is about streaming (`<Suspense>`), not code. Use `next/dynamic` only for Client Components; `ssr: false` must be in a Client Component. `loading.tsx` enables instant navigation feedback and partial prefetching. See [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md), [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**: you own route splitting—use router-level `lazy`. Vite emits `modulepreload` links for static imports of the entry and handles `vite:preloadError` for failed dynamic imports. See [vite-react-spa](../vite-react-spa/Skill.md), [react-router-framework-mode](../react-router-framework-mode/Skill.md), [tanstack-router-and-start](../tanstack-router-and-start/Skill.md).

## AI Agent Guidance
- Do: justify each split with size (analyzer) and trigger; add a size-stable fallback.
- Do: add preload-on-intent for interaction-triggered chunks.
- Don't: wrap every component in `lazy`; don't lazy-load above-the-fold content; don't use `ssr: false` in Server Components.
- Before declaring done: network panel shows deferred chunk absent on load and present on trigger; no CLS from fallback; interaction still < 200 ms on 4× CPU; chunk-failure path handled.

## Examples
```tsx
// Next.js: modal content loaded on open, warmed on hover
'use client';
import dynamic from 'next/dynamic';
import { useState } from 'react';

const importShare = () => import('./share-dialog');
const ShareDialog = dynamic(importShare);

export function ShareButton({ url }: { url: string }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onMouseEnter={() => void importShare()} onFocus={() => void importShare()} onClick={() => setOpen(true)}>
        Share
      </button>
      {open && <ShareDialog url={url} onClose={() => setOpen(false)} />}
    </>
  );
}
```

## Related Skills
- [bundle-optimization](../bundle-optimization/Skill.md) — finding what to split
- [hydration-strategies](../hydration-strategies/Skill.md) — deferring hydration cost
- [speculation-rules-and-prerendering](../speculation-rules-and-prerendering/Skill.md) — prefetch/prerender for MPA navigations
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md) — boundaries and fallbacks
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — streaming server content
- [loading-states](../loading-states/Skill.md) — fallback UX
- [image-optimization](../image-optimization/Skill.md) — lazy media

## Sources
- [Next.js: Lazy Loading](https://nextjs.org/docs/app/guides/lazy-loading) — Official — next/dynamic, ssr:false rules
- [React: lazy](https://react.dev/reference/react/lazy) — Official — lazy/Suspense semantics
- [Vite: Build — load error handling](https://vite.dev/guide/build) — Official — `vite:preloadError`, modulepreload
- [Patterns.dev: Import on Interaction / Visibility, PRPL](https://www.patterns.dev/) — Community — loading patterns
- [web.dev: Browser-level image lazy loading](https://web.dev/articles/browser-level-image-lazy-loading) — Official — native lazy loading guidance

## License / Usage Notes
Docs summarized; React/Next.js/Vite are MIT. Examples original.

## Quality Tier
A — Official APIs and well-established patterns; thresholds for "worth splitting" are heuristic.

## Status
Active

## Last Verified
2026-09-15
