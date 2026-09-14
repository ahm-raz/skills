# Manifest — W13 Animation & Motion

Scope: React + Next.js (TypeScript) per the TAXONOMY scope note of 2026-09-15. Last verified 2026-09-15.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| motion-for-react | Motion for React | Animation | React, Next.js | A | Active | https://motion.dev/docs/react |
| gsap-animation | GSAP Animation | Animation | React, Next.js | A | Active | https://gsap.com/resources/React/ |
| css-animations-and-transitions | CSS Animations and Transitions | Animation | Platform (via React/Next.js) | A | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/@starting-style |
| view-transitions-api | View Transitions API | Animation | React 19.3, Next.js App Router | S | Active | https://react.dev/reference/react/ViewTransition |
| scroll-driven-animations | Scroll-Driven Animations | Animation | Platform (via React/Next.js) | A | Active (scroll-triggered: Experimental) | https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/animation-timeline |
| micro-interactions | Micro-interactions | Animation | React, Next.js | A | Active | https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md |
| layout-animations | Layout Animations | Animation | React, Next.js | A | Active | https://motion.dev/docs/react-layout-animations |
| animation-performance | Animation Performance | Animation | React, Next.js | A | Active | https://web.dev/articles/animations-guide |
| motion-design-principles | Motion Design Principles | Animation | Framework-agnostic (TS tokens) | A | Active | https://m3.material.io/styles/motion/easing-and-duration/tokens-specs |
| lottie-and-rive | Lottie and Rive | Animation | React, Next.js | B | Active | https://docs.lottiefiles.com/en/runtimes/distributions/js |
| 3d-web-three-and-r3f | 3D on the Web: three.js and React Three Fiber | Animation | React, Next.js | B | Active | https://r3f.docs.pmnd.rs/getting-started/installation |
| web-animations-api (ADDED) | Web Animations API (WAAPI) | Animation | Platform (via React/Next.js) | A | Active | https://developer.mozilla.org/en-US/docs/Web/API/Web_Animations_API |

Skipped: `svelte-and-vue-animation` (out of scope after the React/Next.js-only decision; never written). AutoAnimate content moved into `layout-animations` (React hook).

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Motion for React docs | https://motion.dev/docs/react | Official | Package `motion`, `motion/react` import, default spring/tween behavior | Canonical React animation API | High | 2026-09-15 |
| Motion changelog | https://motion.dev/changelog | Official | 13.2.0 latest; 13.1.1 AnimatePresence + React 19 strict-mode fix; motion/three effects | Version currency | High | 2026-09-15 |
| Motion AnimatePresence | https://motion.dev/docs/react-animate-presence | Official | Modes, propagate, key rules, common mistakes | Exit animation correctness | High | 2026-09-15 |
| Motion layout animations | https://motion.dev/docs/react-layout-animations | Official | layout/layoutId/LayoutGroup/layoutScroll/layoutRoot, distortion fixes | Layout animation patterns | High | 2026-09-15 |
| Motion accessibility | https://motion.dev/docs/react-accessibility | Official | MotionConfig reducedMotion semantics, useReducedMotion | Reduced motion defaults | High | 2026-09-15 |
| Motion bundle size | https://motion.dev/docs/react-reduce-bundle-size | Official | LazyMotion/m sizes (4.6kb, +15kb, +25kb), mini useAnimate 2.3kb | Bundle decisions | High | 2026-09-15 |
| Motion performance tier list | https://motion.dev/docs/performance | Official | WAAPI acceleration; independent transforms not accelerated; substitutions | Performance rules | High | 2026-09-15 |
| GSAP React guide | https://gsap.com/resources/React/ | Official | useGSAP scope/dependencies/revertOnUpdate/contextSafe, "use client" | React/Next integration | High | 2026-09-15 |
| GSAP ScrollTrigger | https://gsap.com/docs/v3/Plugins/ScrollTrigger/ | Official | Config options, refresh, batch, normalizeScroll; docs v3.15 | Scroll storytelling | High | 2026-09-15 |
| gsap.matchMedia() | https://gsap.com/docs/v3/GSAP/gsap.matchMedia()/ | Official | Conditions syntax, reduced motion, auto-revert | Accessible GSAP | High | 2026-09-15 |
| GSAP Flip | https://gsap.com/docs/v3/Plugins/Flip/ | Official | getState/from options, framework gotchas | FLIP in React | High | 2026-09-15 |
| GSAP 3.13 release / Webflow announcement | https://webflow.com/blog/gsap-becomes-free | Official | All plugins free incl. commercial; Webflow acquisition | Licensing change | High | 2026-09-15 |
| GSAP Standard License | https://gsap.com/community/standard-license/ | Official | License type (no-charge, proprietary) | Legal usage | Medium (restriction wording not re-read in full) | 2026-09-15 |
| CSS-Tricks: GSAP free | https://css-tricks.com/gsap-is-now-completely-free-even-for-commercial-use/ | Community | Confirmation/context of licensing | Corroboration | Medium | 2026-09-15 |
| React 19.3 release | https://react.dev/blog/2026/09/09/react-19-3 | Official | ViewTransition stable, triggers, addTransitionType, Suspense behavior | Core route-transition API | High | 2026-09-15 |
| React ViewTransition reference | https://react.dev/reference/react/ViewTransition | Official | Props→view-transition-class, callbacks, caveats | Implementation details | High | 2026-09-15 |
| Next.js view transitions guide | https://nextjs.org/docs/app/guides/view-transitions | Official | No-config App Router support, Link/router transitionTypes, CSS recipes, reduced motion (docs v16.3.5) | Next.js route animation | High | 2026-09-15 |
| MDN View Transition API | https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API | Official | Pseudo-elements, types, pageswap/pagereveal, activeViewTransition | Platform reference | High | 2026-09-15 |
| Chrome: View transitions in 2025 | https://developer.chrome.com/blog/view-transitions-in-2025 | Official | Firefox 144 same-doc, match-element (137), nested groups (140), scoped VT, activeViewTransition (142) | Browser status | High | 2026-09-15 |
| Chrome view transitions docs | https://developer.chrome.com/docs/web-platform/view-transitions | Official | Same-doc/cross-doc support matrix | Browser status | Medium (page dated 2024) | 2026-09-15 |
| Can I use: cross-document VT | https://caniuse.com/cross-document-view-transitions | Community | Chrome 126, Safari 18.2, Firefox partial 144+ | Cross-doc support | Medium | 2026-09-15 |
| vercel-labs/agent-skills react-view-transitions | https://github.com/vercel-labs/agent-skills | Community | Agent skill scope/do-don't | Community agent skill reference | Medium | 2026-09-15 |
| MDN @starting-style | https://developer.mozilla.org/en-US/docs/Web/CSS/@starting-style | Official | Syntax, popover/dialog patterns, Baseline 2024 versions | Entry animations | High | 2026-09-15 |
| MDN transition-behavior | https://developer.mozilla.org/en-US/docs/Web/CSS/transition-behavior | Official | allow-discrete, display flip timing | Exit animations | High | 2026-09-15 |
| MDN linear() | https://developer.mozilla.org/en-US/docs/Web/CSS/easing-function/linear | Official | Syntax, spring approximation, Baseline widely available | Easing | High | 2026-09-15 |
| MDN interpolate-size | https://developer.mozilla.org/en-US/docs/Web/CSS/interpolate-size | Experimental | height:auto animation; Chromium-only | Progressive enhancement | Medium | 2026-09-15 |
| MDN animation-timeline | https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/animation-timeline | Official | Values, related properties, shorthand reset caveat | Scroll-driven syntax | High (compat summary unreliable; cross-checked) | 2026-09-15 |
| WebKit scroll-driven guide | https://webkit.org/blog/17101/a-guide-to-scroll-driven-animations-with-just-css/ | Official | Safari support, patterns, reduced motion | Safari status | High | 2026-09-15 |
| WebKit Safari 26.0 features | https://webkit.org/blog/17333/webkit-features-in-safari-26-0/ | Official | Scroll-driven animations shipped; progress() | Safari status | High | 2026-09-15 |
| MDN Firefox experimental features | https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Experimental_features | Official | Scroll-driven animations flag, Nightly-only default | Firefox status | High | 2026-09-15 |
| Chrome: scroll-triggered animations | https://developer.chrome.com/blog/scroll-triggered-animations | Experimental | animation-trigger/timeline-trigger syntax; Chrome 145 | Emerging feature | Medium | 2026-09-15 |
| web.dev animations guide | https://web.dev/articles/animations-guide | Official | Compositor-only properties, will-change, DevTools | Performance baseline | High | 2026-09-15 |
| Material 3 motion tokens (material-web) | https://github.com/material-components/material-web | Open Source | Easing cubic-beziers and duration tokens | Motion token values | High | 2026-09-15 |
| Apple HIG Motion | https://developer.apple.com/design/human-interface-guidelines/motion | Official | Purposeful/brief/optional motion (page JS-rendered; summarized from general guidance) | Platform design guidance | Medium | 2026-09-15 |
| emilkowalski/skills (emil-design-eng) | https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md | Community | Duration table, curves, press scale, frequency rules, clip-path, hover gating | Practitioner agent skill | High | 2026-09-15 |
| Emil Kowalski: 7 practical animation tips | https://emilkowal.ski/ui/7-practical-animation-tips | Community | Scale on press, no scale(0), tooltip delay skip, origin-aware, blur | Practitioner rules | High | 2026-09-15 |
| vercel-labs open-agents web-animation-design | https://github.com/vercel-labs/open-agents/blob/main/.agents/skills/web-animation-design/SKILL.md | Community | Easing decision flow, duration table, anti-patterns | Community agent rules | Medium (stricter reduced-motion stance conflicts with Motion docs) | 2026-09-15 |
| Josh Comeau: spring physics | https://www.joshwcomeau.com/animation/a-friendly-introduction-to-spring-physics/ | Community | Springs vs easing, interruptibility | Motion principles | High | 2026-09-15 |
| AutoAnimate | https://auto-animate.formkit.com/ | Open Source | useAutoAnimate, limitations, reduced motion default | Lightweight layout animation | Medium | 2026-09-15 |
| R3F installation | https://r3f.docs.pmnd.rs/getting-started/installation | Official | v9↔React 19, Next.js transpilePackages | 3D integration | High | 2026-09-15 |
| R3F scaling performance | https://r3f.docs.pmnd.rs/advanced/scaling-performance | Official | Demand frameloop, instancing, LOD, PerformanceMonitor | 3D performance | High | 2026-09-15 |
| dotLottie web runtime | https://docs.lottiefiles.com/en/runtimes/distributions/js | Official | Packages, ThorVG WASM, renderConfig, worker, destroy; 0.x | Lottie runtime | Medium (0.x API churn) | 2026-09-15 |
| Rive web runtime | https://rive.app/docs/runtimes/web/web-js | Official | webgl2/canvas/canvas-lite, state machines, data binding, cleanup | Rive runtime | Medium | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| UI animation durations & easings | Material 3 tokens + emilkowalski/skills | vercel-labs web-animation-design, Emil's 7 tips, Apple HIG | motion-design-principles (tokens), referenced by micro-interactions, css-animations-and-transitions |
| FLIP / layout animation | Motion layout docs | GSAP Flip, AutoAnimate, React ViewTransition update/share, manual WAAPI FLIP | layout-animations |
| Route/page transitions in Next.js | Next.js view transitions guide + React ViewTransition ref | Motion AnimatePresence route patterns, template.tsx approaches, vercel react-view-transitions skill | view-transitions-api |
| Reduced-motion handling | MDN / WCAG 2.3.3 (owned by W11 reduced-motion-and-vestibular-safety) | Motion MotionConfig, gsap.matchMedia, Svelte prefersReducedMotion (dropped: out of scope) | Per-skill Accessibility sections; canonical in reduced-motion-and-vestibular-safety (W11) |
| Compositor-only properties | web.dev animations guide | Motion performance tier list, Emil's rules | animation-performance |
| Scroll-linked effects | MDN animation-timeline / WebKit guide | GSAP ScrollTrigger, Motion useScroll | scroll-driven-animations (CSS), gsap-animation (pinning) |
| Framework transition systems (Vue `<Transition>`, Svelte transitions, motion-v) | — | Researched then dropped per scope change | Skipped (svelte-and-vue-animation) |

## Gaps

- WebSearch budget was exhausted early, so research relied on direct WebFetch of official docs. Practitioner sources (Val Head, Rachel Nabors, the Disney principles) are cited from established knowledge and weren't re-fetched.
- Firefox status needs re-checking. Scroll-driven animations are flag-only in release (MDN); cross-document view transitions show "partial" on caniuse, and exactly what's missing isn't confirmed. Safari/Firefox versions for `match-element`, `document.activeViewTransition`, and VT types are marked "Check".
- The three.js WebGPURenderer manual page returned 404. The R3F + WebGPU `gl` async factory pattern and current three.js revision weren't verified. R3F v10 status is unknown.
- dotLottie (0.x) state-machine APIs and Rive data-binding React hook names change frequently and weren't verified in detail.
- The GSAP Standard License restriction wording (competing with Webflow) wasn't re-read verbatim.
- Whether React Router navigations run inside React Transitions (to activate `<ViewTransition>`) by version and config wasn't verified.
- The CSS scroll-triggered animations (`animation-trigger`) syntax is new and Chrome-only, and may change.
- Material 3 Expressive (spring-based motion scheme) isn't covered. The M3 site is JS-rendered, so only material-web token files were fetched.
- Community sources disagree on reduced motion. vercel-labs says disable everything; Motion docs and Emil keep opacity and color. The skills follow the latter, with the stricter option noted.
- There's no dedicated skill for drag/gesture physics (swipe, momentum) beyond Motion drag coverage; it could become a future slug.
- Community `.cursor/rules` for animation were only lightly surveyed (Emil's and Vercel's skills were the main community inputs).
