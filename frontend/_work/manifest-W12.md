# Manifest — W12 Performance

Scope: React + Next.js (TypeScript) per the TAXONOMY scope note. Framework Notes cover React (Vite SPA) and Next.js only. React re-render tuning links to W02 `react-performance-optimization`; Next.js route-level tuning links to W03 `nextjs-performance`.

Research note: the session's WebSearch budget ran out partway through research. The rest of the verification used WebFetch against official docs (web.dev, Chrome for Developers, MDN, Next.js 16.3.5 docs, Vite docs, Vercel docs, GitHub READMEs and changelogs).

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| core-web-vitals | Core Web Vitals | Performance | React, Next.js | S | Active | https://web.dev/articles/vitals |
| lcp-optimization | LCP Optimization | Performance | React, Next.js | S | Active | https://web.dev/articles/optimize-lcp |
| inp-optimization | INP Optimization | Performance | React, Next.js | S | Active | https://web.dev/articles/optimize-inp |
| cls-prevention | CLS Prevention | Performance | React, Next.js | S | Active | https://web.dev/articles/optimize-cls |
| bundle-optimization | Bundle Optimization | Performance | React (Vite 8), Next.js 16 | A | Active | https://nextjs.org/docs/app/guides/package-bundling |
| code-splitting-and-lazy-loading | Code Splitting and Lazy Loading | Performance | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/lazy-loading |
| image-optimization | Image Optimization | Performance | React, Next.js | A | Active | https://nextjs.org/docs/app/api-reference/components/image |
| font-loading-performance | Font Loading Performance | Performance | React, Next.js | A | Active | https://web.dev/articles/font-best-practices |
| hydration-strategies | Hydration Strategies | Performance | React, Next.js | A | Active | https://nextjs.org/docs/app/getting-started/server-and-client-components |
| rendering-performance | Rendering Performance | Performance | React, Next.js | A | Active | https://web.dev/articles/rendering-performance |
| javascript-memory-leaks | JavaScript Memory Leaks | Performance | React, Next.js | A | Active | https://developer.chrome.com/docs/devtools/memory-problems |
| resource-hints-and-network-optimization | Resource Hints and Network Optimization | Performance | React, Next.js | A | Active | https://web.dev/articles/fetch-priority |
| http-caching-and-cdn | HTTP Caching and CDN | Performance | React (Vite SPA), Next.js | A | Active | https://www.rfc-editor.org/rfc/rfc9111 |
| service-workers-and-offline | Service Workers and Offline | Performance | React (vite-plugin-pwa), Next.js (Serwist) | B | Active | https://developer.chrome.com/docs/workbox |
| performance-profiling-devtools | Performance Profiling with DevTools | Performance | React, Next.js | S | Active | https://developer.chrome.com/docs/devtools/performance/reference |
| performance-budgets-and-rum | Performance Budgets and RUM | Performance | React, Next.js | A | Active | https://github.com/GoogleChrome/web-vitals |
| third-party-script-management | Third-Party Script Management | Performance | React, Next.js | A | Active | https://nextjs.org/docs/app/api-reference/components/script |
| web-workers-offloading | Web Workers Offloading | Performance | React, Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers |
| speculation-rules-and-prerendering | Speculation Rules and Prerendering | Performance | React, Next.js | A | Active | https://developer.chrome.com/docs/web-platform/prerender-pages |
| back-forward-cache | Back/Forward Cache (bfcache) — **added slug** | Performance | React, Next.js | A | Active | https://web.dev/articles/bfcache |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| web.dev Web Vitals | https://web.dev/articles/vitals | Official | Metric definitions, p75 thresholds | Canonical CWV definitions | S | 2026-09-15 |
| web.dev Optimize LCP | https://web.dev/articles/optimize-lcp | Official | LCP subparts and target shares, fetchpriority/preload guidance | Core LCP methodology | S | 2026-09-15 |
| web.dev Optimize INP | https://web.dev/articles/optimize-inp | Official | INP phases, yielding, DOM size, content-visibility | Core INP methodology | S | 2026-09-15 |
| web.dev LCP & INP Baseline | https://web.dev/blog/lcp-and-inp-are-now-baseline-newly-available | Official | Safari 26.2 (Dec 2025) adds LCP + Event Timing | Cross-browser field measurement | S | 2026-09-15 |
| GoogleChrome/web-vitals README + CHANGELOG | https://github.com/GoogleChrome/web-vitals | Open Source | v6.0 (Jul 2026) soft navs `reportSoftNavs`; v5 removed onFID; attribution fields; thresholds; v6.2 bfcache CLS fix | RUM implementation | S | 2026-09-15 |
| Chrome Soft Navigations | https://developer.chrome.com/docs/web-platform/soft-navigations-experiment | Official | Soft-nav measurement shipped in Chrome 151; per-nav LCP/INP semantics | SPA/App Router metrics | A | 2026-09-15 |
| MDN Scheduler.yield | https://developer.mozilla.org/en-US/docs/Web/API/Scheduler/yield | Official | API semantics | INP yielding | A | 2026-09-15 |
| DebugBear scheduler.yield guide | https://www.debugbear.com/blog/scheduler-yield | Community | Chrome 129 / Firefox 142 support, no Safari; fallback pattern | Support matrix | A | 2026-09-15 |
| MDN PerformanceLongAnimationFrameTiming | https://developer.mozilla.org/en-US/docs/Web/API/PerformanceLongAnimationFrameTiming | Official | LoAF fields; experimental, not Baseline | INP attribution | A | 2026-09-15 |
| Chrome Prerender pages | https://developer.chrome.com/docs/web-platform/prerender-pages | Official | Rule syntax, eagerness incl. `immediate`, mobile eager behavior, limits (50/10, 2 FIFO), header delivery, support | Speculation rules skill | S | 2026-09-15 |
| Chrome prerender_until_script OT | https://developer.chrome.com/blog/prerender-until-script-origin-trial | Official | Origin trial from Chrome 144 | Experimental option | A | 2026-09-15 |
| MDN Speculation Rules API | https://developer.mozilla.org/en-US/docs/Web/API/Speculation_Rules_API | Official | Rule reference, CSP keyword | Implementation detail | A | 2026-09-15 |
| web.dev bfcache | https://web.dev/articles/bfcache | Official | pageshow/pagehide, blockers, unload deprecation, DevTools tester, notRestoredReasons | bfcache skill | S | 2026-09-15 |
| Chrome bfcache + no-store | https://developer.chrome.com/docs/web-platform/bfcache-ccns | Official | 2025 rollout, 3-minute limit, cookie-change eviction | Caching/bfcache interplay | A | 2026-09-15 |
| Chrome DevTools Performance reference | https://developer.chrome.com/docs/devtools/performance/reference | Official | Live metrics + CrUX, throttling calibration, insights, annotations, 3rd-party dimming | Profiling skill | S | 2026-09-15 |
| Lighthouse 13 | https://developer.chrome.com/blog/lighthouse-13-0 | Official | Insight-based audits, unchanged scoring | Lab tooling status | A | 2026-09-15 |
| Chrome DevTools MCP tool reference | https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md | Open Source | performance_start/stop_trace, performance_analyze_insight, emulate, resize_page | Agent profiling loop | A | 2026-09-15 |
| Next.js Package Bundling guide (v16.3.5) | https://nextjs.org/docs/app/guides/package-bundling | Official | `next experimental-analyze` (16.1+), `@next/bundle-analyzer` (webpack), optimizePackageImports, serverExternalPackages | Bundle skill | S | 2026-09-15 |
| Next.js Image API (v16.3.5) | https://nextjs.org/docs/app/api-reference/components/image | Official | `priority` deprecated → `preload` (v16), docs prefer `loading="eager"`/`fetchPriority`; `qualities` required default [75]; formats; minimumCacheTTL | Image/LCP skills | S | 2026-09-15 |
| Next.js Font API (v16.3.5) | https://nextjs.org/docs/app/api-reference/components/font | Official | display default swap, preload default, adjustFontFallback, preload scoping | Font/CLS skills | S | 2026-09-15 |
| Next.js Script API (v16.3.5) | https://nextjs.org/docs/app/api-reference/components/script | Official | Strategies; `worker` not in App Router; onLoad/onReady client-only | Third-party skill | S | 2026-09-15 |
| Vercel Speed Insights | https://vercel.com/docs/speed-insights | Official | RES free, Plus for per-metric CWV/breakdowns, preview tracking | RUM for Next.js on Vercel | A | 2026-09-15 |
| Vite 8 announcement | https://vite.dev/blog/announcing-vite8 | Official | Rolldown unified bundler, stable Mar 2026 | Build tooling status | A | 2026-09-15 |
| Vite build options | https://vite.dev/config/build-options | Official | `build.rolldownOptions` (rollupOptions deprecated), target `baseline-widely-available`, chunkSizeWarningLimit, license | Bundle config | A | 2026-09-15 |
| size-limit | https://github.com/ai/size-limit | Open Source | Config fields, presets, size-limit-action | CI budgets | A | 2026-09-15 |
| web.dev HTTP cache | https://web.dev/articles/http-cache | Official | Versioned vs unversioned strategy; no-cache vs no-store; validators | Caching skill | A | 2026-09-15 |
| RFC 9111 / RFC 5861 / RFC 9213 | https://www.rfc-editor.org/rfc/rfc9111 | Official | Directive semantics, SWR/SIE, CDN-Cache-Control | Standards basis | S | 2026-09-15 |
| web.dev Font best practices | https://web.dev/articles/font-best-practices | Official | WOFF2, unicode-range, font-display, preload caution | Font skill | A | 2026-09-15 |
| MDN Image types | https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types | Official | AVIF/WebP universal; JPEG XL Safari 17+, Chrome 145 flag | Format decisions | A | 2026-09-15 |
| Chrome Shared dictionary compression | https://developer.chrome.com/blog/shared-dictionary-compression | Official | Use-As-Dictionary, Available-Dictionary, dcb/dcz | Network optimization | B | 2026-09-15 |
| GoogleChrome/workbox | https://github.com/GoogleChrome/workbox | Open Source | v7; maintenance moved to Chrome Aurora team | SW tooling status | A | 2026-09-15 |
| Partytown (QwikDev) | https://partytown.qwik.dev/ | Open Source | Beta status, limitations | Third-party offload | B | 2026-09-15 |
| DebugBear: Firefox/Safari Web Vitals | https://www.debugbear.com/blog/firefox-safari-web-vitals | Community | Safari INP bugs caveat | Data interpretation | B | 2026-09-15 |
| RUMvision: Safari 26.2 LCP/INP | https://www.rumvision.com/blog/safari-catching-up-inp-and-lcp-support-in-the-same-beta-release/ | Community | Safari release timing | Cross-browser context | B | 2026-09-15 |
| addyosmani/web-quality-skills | https://github.com/addyosmani/web-quality-skills | Open Source (MIT) | Community agent skills (performance, core-web-vitals); thresholds; budget suggestions | Compared community SKILL.md structure | B | 2026-09-15 |
| Comlink | https://github.com/GoogleChromeLabs/comlink | Open Source | expose/wrap/transfer API | Worker skill | A | 2026-09-15 |
| React docs (lazy, Suspense, Profiler, cache, 19.2 release) | https://react.dev/ | Official | lazy/Suspense semantics, Activity, performance tracks, Profiler API, cache | React integration | A | 2026-09-15 |
| Patterns.dev | https://www.patterns.dev/ | Community | Import-on-interaction/visibility, PRPL, islands concepts | Loading patterns | B | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| CWV thresholds & definitions | web.dev Web Vitals | addyosmani/web-quality-skills core-web-vitals skill; vendor blog restatements | core-web-vitals |
| LCP subparts methodology | web.dev Optimize LCP | DebugBear/Calibre LCP breakdown articles; DevTools LCP breakdown insight | lcp-optimization |
| Yielding / long tasks | web.dev Optimize long tasks + MDN scheduler.yield | DEV.to / OpenReplay scheduler articles | inp-optimization |
| Lighthouse audits vs DevTools insights | Chrome "Lighthouse 13" blog | DebugBear insights article; SEJ coverage | performance-profiling-devtools |
| next/image & next/font performance | Next.js API docs | — (deep config owned by W03) | image-optimization, font-loading-performance (link to nextjs-image-and-font-optimization) |
| React re-render optimization | react.dev | — (owned by W02) | Not duplicated; linked to react-performance-optimization |
| Next.js route-level performance | Next.js docs | — (owned by W03) | Not duplicated; linked to nextjs-performance |
| Lab budgets in CI | Lighthouse CI docs | size-limit | performance-budgets-and-rum (LHCI details linked to W16 lighthouse-ci) |
| Animation frame performance | web.dev rendering performance | — (motion owned by W13) | rendering-performance (links animation-performance) |
| no-store & bfcache | Chrome bfcache-ccns doc | RUMvision, Joomla issue | back-forward-cache, http-caching-and-cdn |

## Gaps

- **Added slug:** `back-forward-cache`. It's a distinct, high-value topic not owned by any workstream. Other W12 skills now link to it; other workstreams can too.
- **Skipped slugs:** none.
- **Candidate slugs not added:**
  - `mobile-and-low-end-device-performance`: device-class adaptation, `navigator.deviceMemory`, Save-Data. Currently scattered across skills.
  - `nextjs-edge-and-streaming-ttfb`: may be covered by W03.
- **Web search budget ran out** midway through research. These claims were not re-verified with fresh searches (WebFetch only, or knowledge-based):
  - Current Serwist and vite-plugin-pwa API details.
  - MemLab maintenance status.
  - `@next/third-parties` experimental status.
  - Turbopack `new Worker(new URL())` support.
  - Early Hints browser and CDN support matrix.
  - Compression Dictionary Transport shipping status (the fetched Chrome blog still described an origin trial; my knowledge says it shipped in Chromium 130).
  - Safari support for font `ascent-override`/`descent-override`.
  - React 19.2 performance tracks naming.
- **Next.js default `Cache-Control` headers** per rendering mode are summarized, not fetched from current docs. They should be checked with `curl -I` for Next 16 and Cache Components.
- **Budget numbers** (JS KB per route, DOM size, third-party limits) are pragmatic heuristics, not standards.
- **Community agent rules:** only one repo was reviewed in depth (addyosmani/web-quality-skills). `.cursor/rules` and AGENTS.md performance rules were not surveyed because of the search budget.
- **Safari INP accuracy** (known bugs in early 26.x) and how RUM vendors normalize it need follow-up.
- **CrUX soft-navigation support:** whether CrUX will report soft-navigation metrics after Chrome 151 is unconfirmed.
