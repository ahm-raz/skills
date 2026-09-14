# Low-End Device Performance

## Summary
Make React and Next.js apps fast on the devices most people actually use: budget Android phones, low-cost Celeron laptops, and slow or expensive mobile networks. This skill sets realistic budgets based on device class, explains how to throttle and test honestly, and shows how to reduce JavaScript and hydration cost with React Server Components and smaller client boundaries. It also covers adapting what you load using Save-Data, Device Memory, and Network Information, always as progressive enhancement.

## Category
Performance

## Subcategories
Device-class budgets, CPU/network throttling, adaptive loading, Save-Data, Device Memory, Network Information API, client hints, hydration cost, INP on slow CPUs, real-device testing, RUM segmentation

## Problem It Solves
Developers test on flagship phones and M-series laptops that are several times faster than the 75th-percentile user's device. JavaScript costs far more per byte on slow CPUs than images or HTML, because it has to be parsed, compiled, and executed, and then hydration runs on top. The result is a site that scores well in local testing but fails LCP and INP in the field, especially in emerging markets. This skill makes the slow-device experience the baseline you design for.

## When To Use
- CrUX or RUM shows poor mobile LCP or INP, or users come from markets dominated by budget Android devices.
- Setting performance budgets or CI gates for a new product.
- Deciding what goes in `'use client'`, what gets lazy-loaded, and what can be skipped on constrained devices.
- Adding heavy features such as video, maps, 3D, rich editors, or animation libraries.

## When Not To Use
- Internal tools with a known high-end device fleet. Still measure, but these budgets can be relaxed.
- Fixing a specific metric in depth. Use [inp-optimization](../inp-optimization/Skill.md), [lcp-optimization](../lcp-optimization/Skill.md), or [bundle-optimization](../bundle-optimization/Skill.md). This skill sets the device context and adaptation strategy.
- Deciding whether to adapt based on User-Agent sniffing. Don't; use capability signals instead.

## Core Principles
1. **Design for the P75 device and network, not your own.** Alex Russell's 2026 baseline: a Samsung Galaxy A24 4G-class phone (Helio G99 / Exynos 1330), a Celeron/eMMC laptop, and about 9 Mbps down / 3 Mbps up / 100 ms RTT.
2. **JavaScript is the most expensive resource.** Budget JS separately from total page weight.
3. **The baseline works everywhere, and enhancements are optional.** Adaptive loading only removes or defers extras. It never removes core functionality.
4. **Signals are hints, not guarantees.** Device Memory and Network Information are Chromium-only (not Baseline) and deliberately coarse. When a signal is missing, serve the full or default experience. Don't assume "low".
5. **Server-render and send less hydration.** Every `'use client'` subtree costs download, parse, execute, and hydration time.
6. **Measure in the field, segmented by device class.** Lab throttling is an approximation, and DevTools can't truly emulate mobile CPUs.

## Best Practices
- Adopt budgets from the 2026 Inequality Gap article. For a 3-second target on the P75 device and network: about 2.0 MiB total with about 0.3 MiB JS for markup-heavy sites, or about 1.2 MiB total with about 0.62 MiB JS for JS-heavy apps. The article's 5-second targets are about 3.7 MiB / 0.57 MiB and 2.3 MiB / 1.15 MiB. These budgets assume two TLS connections, and each extra early connection lowers them.
- Enforce the budgets in CI on compressed JS per route. See [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md).
- Keep Client Components as leaves. Pass server-rendered content as `children` into interactive shells. Don't mark layouts or pages `'use client'`.
- Keep the RSC payload small. Pass the fields a Client Component needs, not whole database records.
- Lazy-load interaction-only code (modals, editors, charts, emoji pickers) with `next/dynamic` or `import()` when the user acts.
- Respect `Save-Data`: don't autoplay video, use `preload="none"`, serve lower image quality, skip decorative media and web fonts, and don't prefetch aggressively.
- On low-memory or low-core devices, skip optional heavy features (3D, parallax, particle effects, large animation libraries) and render a static fallback.
- Break up long tasks in event handlers (`scheduler.yield()` with a fallback, `startTransition`). Virtualize long lists and use `content-visibility: auto` for long off-screen sections.
- Audit third-party scripts first. Tag managers and chat widgets often cost more than the app itself on slow CPUs. See [third-party-script-management](../third-party-script-management/Skill.md).
- Segment RUM by `deviceMemory`, `hardwareConcurrency`, and `effectiveType` so regressions on low-end devices aren't hidden by averages.

## Implementation Guidance

**Throttling setups**

| Goal | Setup |
|---|---|
| Quick local check | Chrome DevTools Performance panel: calibrate CPU presets ("low-tier mobile" / "mid-tier mobile") on your machine; network "Slow 4G"; or the CrUX-recommended preset in environment settings |
| Custom network | DevTools custom profile at about 9000 kbps down / 3000 kbps up / 100 ms latency (P75 baseline), plus a harsher 1.6 Mbps / 150 ms profile |
| Lighthouse | Mobile preset uses simulated throttling (4x CPU slowdown, slow-4G-like network). Treat the scores as relative, not absolute |
| Realistic lab | WebPageTest on real mid/low-end Android devices or the Moto G-class profile, 3+ runs, first and repeat view, filmstrip. Check current docs for device availability |
| Ground truth | A physical budget Android phone (about $150-200 class) over USB with `chrome://inspect`, on cellular, battery not charging |

**Adaptive signal matrix (client)**

| Signal | API | Support | Suggested use |
|---|---|---|---|
| Save-Data | `navigator.connection.saveData`, `Save-Data: on` header | Chromium | Disable autoplay, prefetch, decorative media; lower image quality |
| Effective connection | `navigator.connection.effectiveType` (`slow-2g`/`2g`/`3g`/`4g`) | Chromium | Poster instead of video on `2g`/`3g`; smaller placeholders |
| Device memory | `navigator.deviceMemory` (coarse powers of two, clamped; HTTPS) | Chromium | `<= 2` or `<= 4` GiB: skip optional heavy modules |
| CPU cores | `navigator.hardwareConcurrency` | Baseline | `<= 4`: reduce animation and effects, worker pool size |
| Reduced motion | `prefers-reduced-motion` | Baseline | Also cuts animation CPU cost |

**Server-side hints.** The `Save-Data` header is sent automatically when data saver is on. `Sec-CH-Device-Memory` and ECT/RTT/Downlink require `Accept-CH` opt-in, are experimental, and arrive only on later requests. Any response that varies by a hint needs `Vary: Save-Data` (or the hint name). In Next.js, reading `headers()` makes the route dynamic. On static and cached routes, adapt on the client instead, or scope header-based adaptation to image and media endpoints.

**Reducing hydration cost in Next.js**
1. Default to Server Components. Keep `'use client'` for the button, the form, and the carousel, not the section around them.
2. Stream slow data behind `<Suspense>` so the shell paints early.
3. Defer non-critical client islands until visible or idle: `next/dynamic` plus an IntersectionObserver wrapper.
4. Use `ssr: false` only for client-only widgets that aren't needed for first paint. It's only allowed inside Client Components.
5. Use the React Compiler or targeted memoization to avoid re-render storms that slow CPUs magnify.
6. Check the result with bundle analysis per route, and with Performance panel traces under 4-6x CPU throttling, looking at "Evaluate script" and hydration long tasks.

## Recommended Workflow
1. Pull CrUX and RUM data: form factor, top countries, LCP/INP at P75 by device class. Pick a target device and network (default to the 2026 baseline).
2. Set per-route budgets for JS (compressed) and total weight, and add them to CI.
3. Profile the key routes under calibrated low-tier CPU and Slow 4G throttling. Record long tasks, hydration time, and INP of the main interactions.
4. Reduce hydration first: move code to server components, split out client leaves, trim props, and remove unused third parties.
5. Lazy-load interaction-only features, and optimize images and fonts.
6. Add adaptive enhancements (Save-Data, memory, network) for optional media and effects only.
7. Validate on a real budget Android phone and WebPageTest. Then ship and watch RUM segmented by device class.

## Patterns
- **Server shell + client leaf:** a Server Component page renders content, and a small `'use client'` `<AddToCart>` hydrates.
- **Capability gate:** `<Enhance when={caps => !caps.saveData && (caps.memory ?? 8) > 4} fallback={<Poster/>}>{<VideoHero/>}</Enhance>`.
- **Load on intent:** `import()` the heavy library in `onFocus` or `onPointerDown`, not at module scope.
- **Visible-then-hydrate:** an IntersectionObserver wrapper that mounts a `next/dynamic` component near the viewport.
- **Yielding handler:** update the visible state first, `await yieldToMain()`, then do analytics and non-urgent work.
- **Device-class RUM:** attach `deviceMemory`, `hardwareConcurrency`, and `effectiveType` to web-vitals beacons.

## Anti-Patterns
- **Testing only on a MacBook with no throttling.** The results say nothing about users. Fix: calibrated CPU throttling plus a real budget device.
- **`'use client'` at the top of `layout.tsx` or `page.tsx`.** The whole tree ships and hydrates. Fix: push the boundary down to interactive leaves.
- **Treating a missing signal as low-end.** Safari and Firefox users get a degraded site. Fix: default to the standard experience when a signal is undefined.
- **Reading `navigator.*` during render in SSR code.** It causes crashes or hydration mismatches. Fix: `useSyncExternalStore` with a server snapshot, or an effect.
- **Removing core features on "slow" devices.** That breaks parity and confuses users. Fix: adapt only optional media, effects, and prefetching.
- **Autoplaying a background video for everyone.** It wastes data and CPU. Fix: poster image, `preload="none"`, and play only when Save-Data is off and the connection is fast.
- **Header-based adaptation without `Vary`.** A CDN serves the lite version to everyone, or the heavy version to Save-Data users. Fix: `Vary: Save-Data`, or adapt on the client.
- **Passing a 500-item JSON array as props to a Client Component.** It bloats the RSC payload and hydration work. Fix: paginate, or render the list on the server.
- **Relying on Lighthouse desktop scores.** Fix: mobile preset plus field data.

## Accessibility
- Adapting must never remove content or accessibility features: captions, focus styles, labels.
- Posters that replace video still need alt text or accessible names. Lighter components must keep the same keyboard behaviour and semantics.
- Slow hydration delays interactivity. Server-rendered forms and links should work before JS loads. See [progressive-enhancement](../progressive-enhancement/Skill.md).
- Cutting animation on low-end devices fits with `prefers-reduced-motion`. Honour both.

## Responsive Design
- Budget phones often have small, high-DPR screens. Use `sizes` correctly so they don't download desktop-width images, and consider capping DPR for large images.
- Don't use viewport width as a stand-in for device power. A cheap laptop has a wide screen and a slow CPU.

## Performance
- The key costs on slow devices are script evaluation, hydration, long tasks during input, layout and style recalculation on large DOMs, and memory pressure (tab discards on 2-4 GiB devices).
- INP target: 200 ms or less at P75, segmented by mobile and desktop. Low-end devices dominate the P75 tail.
- Web fonts: one or two families, `font-display: swap` or `optional`, and `next/font` subsetting. Skip decorative fonts when Save-Data is on.
- Service workers and prefetch: cap precaching and speculative loads under Save-Data or slow connections.

## Security
- Client hints and capability signals add some fingerprinting surface. Collect only coarse values in RUM, and don't join them with identifiers beyond what your privacy policy allows.
- Don't trust client-sent capability values for anything security-relevant. They're only for choosing a lighter experience.

## Testing
- **Lab:** Performance panel traces under calibrated low-tier CPU and Slow 4G. Lighthouse CI with the mobile preset and per-route budgets. See [lighthouse-ci](../lighthouse-ci/Skill.md).
- **Real devices:** one budget Android phone (Galaxy A-series class) in the team, remote debugging over `chrome://inspect`, and WebPageTest real-device runs.
- **Adaptive paths:** unit-test the capability hook with a mocked `navigator.connection` and `deviceMemory` (including `undefined`). Run Playwright with Chromium CDP `Network.emulateNetworkConditions` and `Emulation.setCPUThrottlingRate`, and set `extraHTTPHeaders: { 'Save-Data': 'on' }` to test header paths.
- **Field:** web-vitals attribution beacons segmented by device class. Alert on low-end P75 regressions.

## Tooling
- Chrome DevTools Performance panel (calibrated CPU throttling, CrUX-based recommendations) (Active).
- Lighthouse / Lighthouse CI (Active), WebPageTest (Active; docs site had a TLS error during verification: Check current docs).
- `web-vitals` library with attribution build (Active).
- `@next/bundle-analyzer` or Turbopack bundle analysis (Check current docs for Next 16.3 tooling).
- `react-adaptive-hooks` (Google Labs, from the 2019 adaptive loading talk). Treat it as unmaintained reference code and prefer the small in-house hook below.

## Framework Notes
- **Next.js (16.x App Router):** RSC by default is the biggest lever. Keep client boundaries small, stream with Suspense, use `next/image` with accurate `sizes`, and use `next/font`. `next/dynamic` with `ssr: false` only works inside Client Components, and Server Components are code-split automatically. Server-side Save-Data adaptation makes routes dynamic via `headers()`, so prefer client adaptation on cached routes. See [react-server-components](../react-server-components/Skill.md), [hydration-strategies](../hydration-strategies/Skill.md), and [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA):** The whole app hydrates or client-renders, so route-level code splitting (`React.lazy`) and a small entry chunk matter more. Consider prerendering or SSR for content routes. Load-on-intent and capability gates apply as-is.

## AI Agent Guidance
- DO check where `'use client'` is placed before adding code. Add new interactivity as a leaf component.
- DO lazy-load new heavy dependencies (charts, editors, maps, animation) and report their bundle cost.
- DO gate only optional features on capability signals, with "unknown" treated as capable.
- DO use `useSyncExternalStore` or effects for `navigator.*`. Never read it during SSR render.
- DON'T add autoplay video, large Lottie or 3D, or new third-party scripts without a Save-Data or capability gate and a static fallback.
- DON'T use User-Agent sniffing for device class.
- Before declaring done: compare per-route JS size before and after, run a Performance trace with CPU throttling on the changed route and confirm no new long tasks over 50 ms during load or key interactions, and state that real-device and field validation are still needed.

## Examples

```tsx
// lib/useDeviceCapabilities.ts — SSR-safe capability snapshot
'use client';
import { useSyncExternalStore } from 'react';

type Conn = { saveData?: boolean; effectiveType?: string; addEventListener?: (t: 'change', f: () => void) => void; removeEventListener?: (t: 'change', f: () => void) => void };
export type Caps = { saveData: boolean; effectiveType?: string; memory?: number; cores?: number };

const SERVER: Caps = { saveData: false }; // unknown on server -> standard experience
let cached: Caps | null = null;

function read(): Caps {
  const nav = navigator as Navigator & { connection?: Conn; deviceMemory?: number };
  const next: Caps = {
    saveData: nav.connection?.saveData === true,
    effectiveType: nav.connection?.effectiveType,
    memory: nav.deviceMemory,
    cores: nav.hardwareConcurrency,
  };
  if (cached && JSON.stringify(cached) === JSON.stringify(next)) return cached;
  return (cached = next);
}

function subscribe(cb: () => void) {
  const conn = (navigator as Navigator & { connection?: Conn }).connection;
  conn?.addEventListener?.('change', cb);
  return () => conn?.removeEventListener?.('change', cb);
}

export function useDeviceCapabilities(): Caps {
  return useSyncExternalStore(subscribe, read, () => SERVER);
}

export const isConstrained = (c: Caps) =>
  c.saveData || c.effectiveType === 'slow-2g' || c.effectiveType === '2g' || c.effectiveType === '3g' ||
  (c.memory !== undefined && c.memory <= 2);
```

```tsx
// app/(marketing)/Hero.tsx — Server Component with an adaptive client leaf
import Image from 'next/image';
import { HeroVideo } from './HeroVideo';

export default function Hero() {
  return (
    <section>
      <h1>Ship faster</h1>
      <HeroVideo poster={<Image src="/hero.avif" alt="Product dashboard" width={1200} height={675} sizes="100vw" priority />} />
    </section>
  );
}
```

```tsx
// app/(marketing)/HeroVideo.tsx
'use client';
import dynamic from 'next/dynamic';
import type { ReactNode } from 'react';
import { useDeviceCapabilities, isConstrained } from '@/lib/useDeviceCapabilities';

const Video = dynamic(() => import('./VideoPlayer'), { ssr: false });

export function HeroVideo({ poster }: { poster: ReactNode }) {
  const caps = useDeviceCapabilities();
  if (isConstrained(caps)) return <>{poster}</>; // poster is server-rendered; no extra JS
  return <Video fallback={poster} />;
}
```

```ts
// lib/yieldToMain.ts — keep handlers responsive on slow CPUs
export function yieldToMain(): Promise<void> {
  const s = (globalThis as { scheduler?: { yield?: () => Promise<void> } }).scheduler;
  if (s?.yield) return s.yield();
  return new Promise((r) => setTimeout(r, 0));
}
// usage in a Client Component handler:
// setOpen(true); await yieldToMain(); track('filter_opened'); recomputeFacets();
```

```ts
// app/reportWebVitals.ts (client) — segment field data by device class
import { onINP, onLCP } from 'web-vitals/attribution';
function send(metric: { name: string; value: number }) {
  const nav = navigator as Navigator & { deviceMemory?: number; connection?: { effectiveType?: string } };
  navigator.sendBeacon('/api/rum', JSON.stringify({
    ...metric, mem: nav.deviceMemory ?? null, cores: nav.hardwareConcurrency ?? null, ect: nav.connection?.effectiveType ?? null,
  }));
}
onINP(send); onLCP(send);
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md): metric definitions and thresholds
- [inp-optimization](../inp-optimization/Skill.md): deep dive on interaction latency, which low-end devices amplify
- [hydration-strategies](../hydration-strategies/Skill.md): partial, deferred, and visible hydration techniques
- [react-server-components](../react-server-components/Skill.md): shrinking client JavaScript
- [bundle-optimization](../bundle-optimization/Skill.md): cutting JS bytes per route
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md): load-on-intent patterns
- [image-optimization](../image-optimization/Skill.md): adaptive image quality and sizes
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md): enforcing budgets, field segmentation
- [performance-profiling-devtools](../performance-profiling-devtools/Skill.md): throttled trace analysis
- [third-party-script-management](../third-party-script-management/Skill.md): the biggest hidden cost on slow CPUs
- [list-virtualization](../list-virtualization/Skill.md): large DOM mitigation
- [web-workers-offloading](../web-workers-offloading/Skill.md): moving CPU work off the main thread
- [nextjs-performance](../nextjs-performance/Skill.md): framework-specific tuning
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md): real-device labs

## Sources
- [The Performance Inequality Gap, 2026 (Alex Russell)](https://infrequently.org/2025/11/performance-inequality-gap-2026/): Community/Expert. P75 devices, network baseline, 3s/5s budgets.
- [The Performance Inequality Gap, 2024](https://infrequently.org/2024/01/performance-inequality-gap-2024/): Community/Expert. Prior baseline for comparison, JS cost rationale.
- [web.dev: Adaptive loading](https://web.dev/articles/adaptive-loading-cds-2019): Official (Google). Signals, React hooks, industry examples, device tiering.
- [web.dev: Delivering fast and light applications with Save-Data](https://web.dev/articles/optimizing-content-efficiency-save-data): Official. Header and JS detection, adaptations, `Vary`.
- [web.dev: Optimize INP](https://web.dev/articles/optimize-inp): Official. Yielding, input delay from script evaluation, DOM size, 200 ms target.
- [MDN: Navigator.deviceMemory](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory): Official. Coarse values, secure context, limited support.
- [MDN: Network Information API](https://developer.mozilla.org/en-US/docs/Web/API/Network_Information_API): Official. Properties, change event, not Baseline.
- [MDN: Sec-CH-Device-Memory](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-CH-Device-Memory): Official. Accept-CH opt-in, experimental status.
- [Chrome DevTools: Performance features reference](https://developer.chrome.com/docs/devtools/performance/reference): Official. CPU calibration, CrUX-based throttling guidance, emulation limits.
- [Chrome DevTools: Throttling](https://developer.chrome.com/docs/devtools/settings/throttling): Official. Calibrated presets, custom network profiles.
- [Next.js: Lazy loading guide](https://nextjs.org/docs/app/guides/lazy-loading): Official (v16.3.5). `next/dynamic`, `ssr: false` constraints, on-demand library imports.

## License / Usage Notes
web.dev text is CC-BY 4.0, MDN is CC-BY-SA, and Next.js docs are MIT-licensed. The infrequently.org articles are the author's copyright, so only the budget figures are summarized and attributed. Code is original. Budget numbers are the author's model, not a standard. Revisit them when a newer edition is published.

## Quality Tier
A: combines official web.dev, MDN, Chrome, and Next.js docs with the current Inequality Gap edition. WebPageTest docs and the exact Lighthouse throttling constants couldn't be re-verified in this pass.

## Status
Active

## Last Verified
2026-09-15
