# Mobile Web App Patterns

## Summary
Patterns for web apps whose primary context is a phone browser: viewport and safe-area handling, the on-screen keyboard, touch ergonomics, mobile navigation (bottom bars, sheets, back-button behavior), mobile-optimized inputs, gestures, network resilience, and platform differences between iOS Safari and Android Chrome. Implementation targets React + Next.js. Installability and offline behavior are covered in [progressive-web-apps](../progressive-web-apps/Skill.md).

## Category
Product Patterns

## Subcategories
Viewport units, safe areas, virtual keyboard, touch targets, bottom navigation, bottom sheets, history and back button, mobile forms, gestures, network resilience, iOS Safari quirks

## Problem It Solves
Desktop-first web apps break on phones in recurring ways:
- `100vh` layouts jump.
- Fixed footers hide behind the keyboard or the home indicator.
- Inputs zoom the page on iOS.
- Modals trap the back button and users leave the app.
- Tap targets are too small, and hover-only UI is unreachable.
- Heavy JavaScript makes interactions sluggish on mid-range Android devices.

This skill gives concrete fixes and structure for mobile-first web apps.

## When To Use
- Consumer apps where most traffic is mobile (commerce, fintech, social, booking, delivery, content).
- Building app-like mobile web experiences (bottom nav, sheets, full-screen flows).
- Fixing mobile layout, keyboard, or touch issues in an existing app.

## When Not To Use
- Install prompts, manifest, service workers, push: [progressive-web-apps](../progressive-web-apps/Skill.md).
- General breakpoint strategy: [responsive-design](../responsive-design/Skill.md).
- Native app development (React Native): out of scope.

## Core Principles
1. **Design for the thumb.** Primary actions belong in the bottom half of the screen, and destructive actions stay away from easy mis-taps.
2. **Respect the dynamic viewport.** Browser chrome and the keyboard change available space. Use `svh`/`dvh`, `interactive-widget`, and safe-area insets, not `100vh`.
3. **The back button is sacred.** Any full-screen overlay a user perceives as a "page" (sheets, full-screen dialogs, image viewers) should close on Back.
4. **Inputs are the mobile bottleneck.** Pick the right keyboard (`inputmode`, `type`), `autocomplete`, `enterkeyhint`, and ≥16px font to avoid iOS zoom.
5. **Mid-range Android is the performance baseline.** Budget JavaScript and main-thread work for a device far slower than your laptop.
6. **Assume flaky networks.** Every action shows pending state, tolerates retries, and preserves user input.
7. **Never disable zoom.** `user-scalable=no` and `maximum-scale=1` break accessibility (WCAG 1.4.4).

## Best Practices
- **Viewport meta:** `width=device-width, initial-scale=1, viewport-fit=cover` (when using safe-area insets), plus `interactive-widget=resizes-content` for input-heavy layouts. It is honored by Chromium and Firefox but ignored by Safari, so test both.
- **Heights:** `min-height: 100svh` for full-screen sections (stable, no jump), `100dvh` only for app shells that must track browser UI, and a `100vh` fallback declared first.
- **Safe areas:** `padding-bottom: max(16px, env(safe-area-inset-bottom))` on bottom bars; `env(safe-area-inset-top)` in standalone display mode.
- **Touch targets:** ≥ 44×44 CSS px for primary controls (Apple HIG 44pt, Material 48dp); WCAG 2.5.8 minimum 24×24 with spacing.
- **Hover:** gate hover effects with `@media (hover: hover) and (pointer: fine)`. Never hide essential actions behind hover.
- **Bottom navigation:** 3–5 top-level destinations with icon + text label, current item marked `aria-current="page"`. Hide on scroll only if it reappears on scroll-up and doesn't cause layout shift.
- **Bottom sheets:** for contextual actions and filters; drag handle is decorative — always provide a close button; snap points optional.
- **Forms:** single column; labels above fields; `type="email"`, `type="tel"`, `inputmode="numeric"` for codes, `autocomplete="one-time-code"` for SMS OTP; `enterkeyhint="next|done|search|send"`.
- **Font size on inputs ≥ 16px** to prevent iOS Safari auto-zoom on focus.
- **Pull-to-refresh:** if you implement custom, set `overscroll-behavior-y: contain` on the scroller to stop native refresh/scroll chaining.
- **Scroll lock for overlays:** use `overflow: hidden` on `html` with `scrollbar-gutter: stable`, or `overscroll-behavior: contain` on the overlay; handle iOS specifically (test).
- **Native capabilities:** Web Share API (`navigator.share`) with a copy-link fallback; `<input type="file" accept="image/*">` for camera/gallery; Vibration API is not supported on iOS.
- **Smart app banners/interstitials:** never full-screen interstitials that block content (Google penalizes intrusive interstitials on mobile).

## Implementation Guidance

### Layout shell (Next.js App Router + CSS)
```tsx
// app/layout.tsx
import type { Viewport } from "next";
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  interactiveWidget: "resizes-content",
  themeColor: [{ media: "(prefers-color-scheme: light)", color: "#ffffff" }, { media: "(prefers-color-scheme: dark)", color: "#0b0b0c" }],
};
```

```css
/* app shell: header, scrolling main, bottom nav */
.shell { display: grid; grid-template-rows: auto 1fr auto; min-height: 100vh; min-height: 100dvh; }
.shell > header { padding-top: env(safe-area-inset-top); position: sticky; top: 0; }
.shell > main { overflow-y: auto; overscroll-behavior-y: contain; }
.bottom-nav { padding-bottom: max(8px, env(safe-area-inset-bottom)); display: grid; grid-auto-flow: column; }
.bottom-nav a { min-height: 48px; display: grid; place-items: center; }
input, select, textarea { font-size: max(16px, 1rem); }
@media (hover: hover) and (pointer: fine) { .card:hover { box-shadow: var(--shadow-2); } }
```

### Back-button-aware sheet (URL-driven)
Model overlays as URL state so Back closes them, deep links work, and there's no history hack.
```tsx
"use client";
import { useRouter, useSearchParams, usePathname } from "next/navigation";

export function useUrlSheet(key: string) {
  const params = useSearchParams(); const router = useRouter(); const pathname = usePathname();
  const open = params.get("sheet") === key;
  const show = () => { const p = new URLSearchParams(params); p.set("sheet", key); router.push(`${pathname}?${p}`, { scroll: false }); };
  const hide = () => router.back(); // pops the history entry pushed by show()
  return { open, show, hide };
}
```
If a user deep-links directly to `?sheet=filters`, `router.back()` would leave the site. Track whether `show()` pushed the entry (sessionStorage flag) and otherwise `router.replace` without the param. In Next.js, intercepting routes (`@modal/(.)photo/[id]`) give the same Back behavior for route-level overlays.

### Keyboard-aware fixed action bar
- With `interactive-widget=resizes-content` (Chromium/Firefox), a bottom-anchored bar in a `dvh` grid rises above the keyboard.
- For Safari, use the `visualViewport` API to offset if needed:
```ts
useEffect(() => {
  const vv = window.visualViewport; if (!vv) return;
  const onResize = () => document.documentElement.style.setProperty("--kb-offset", `${Math.max(0, window.innerHeight - vv.height - vv.offsetTop)}px`);
  vv.addEventListener("resize", onResize); vv.addEventListener("scroll", onResize); onResize();
  return () => { vv.removeEventListener("resize", onResize); vv.removeEventListener("scroll", onResize); };
}, []);
```
Often the simplest and most robust choice is to not fix the action bar while an input is focused. Place the submit button in the flow after the last field.

### Network resilience checklist
| Situation | Behavior |
|-----------|----------|
| Action pending > 300ms | Inline pending state on the control |
| Request failed | Keep input, show retry, explain |
| Offline detected (`navigator.onLine` false / fetch fails) | Non-blocking banner; queue safe actions or disable unsafe ones |
| Slow connection | Skeletons and progressive rendering; avoid spinners covering whole screen |
| Reconnect | Revalidate stale data (TanStack Query `refetchOnReconnect`) |

## Recommended Workflow
1. Define top-level destinations (≤5) and primary per-screen action; sketch thumb zones.
2. Set viewport metadata; build shell with `dvh`/`svh` fallbacks and safe-area padding.
3. Implement navigation: bottom nav + URL-driven overlays (sheets/dialogs) with Back support.
4. Build forms with correct input types, autocomplete, enterkeyhint, and 16px font.
5. Add network states (pending/error/offline) to every mutation.
6. Test on real devices: iOS Safari (latest two versions), Android Chrome on a mid-range device, landscape, with keyboard open, with 200% text size.
7. Measure field INP/LCP on mobile segment and fix regressions.

## Patterns
- **Sticky primary CTA:** bottom bar with price/summary + action on detail pages; hidden when the in-flow CTA is visible.
- **Segmented control for view switching** (List/Map) instead of tabs with small targets.
- **Swipe actions on list rows** with visible alternatives (overflow menu), since swipe is undiscoverable and inaccessible alone.
- **Full-screen search overlay:** autofocus input, recent searches, Back closes.
- **Skeleton-first navigation:** instant route transition with `loading.tsx` skeletons.
- **Pull-to-refresh alternative:** "Updated 2 min ago · Refresh" button at top.

## Anti-Patterns
- **`height: 100vh` on app shells.** Content hides under browser UI on iOS. Fix: `100dvh` with `100vh` fallback, or `svh` for static heroes.
- **Disabling zoom to stop input zoom.** Fix: 16px input font size.
- **Modal that doesn't respond to Back.** Users exit the app. Fix: URL-driven overlays or intercepting routes.
- **Hover-revealed actions.** Unreachable on touch. Fix: always-visible or overflow menu.
- **Fixed bottom bar covering focused inputs or the home indicator.** Fix: safe-area padding; hide or reposition while typing.
- **Gesture-only interactions (swipe to delete, pinch).** Fix: button alternatives (WCAG 2.5.1 Pointer Gestures, 2.5.7 Dragging Movements).
- **Full-page interstitial "Get our app".** Fix: small dismissible banner.
- **Shipping desktop-sized JS bundles to phones.** Fix: route-level splitting, Server Components, and deferred third parties.

## Accessibility
- Don't restrict orientation (WCAG 1.3.4) unless essential.
- Content reflows at 320 CSS px width without horizontal scrolling (1.4.10). Support text resize to 200% (1.4.4).
- Target size ≥ 24×24 minimum (2.5.8); prefer 44–48px.
- Gesture alternatives: single-pointer operation for multipoint/path gestures (2.5.1); non-drag alternatives (2.5.7).
- Motion actuation (shake to undo) must have UI alternatives and be disable-able (2.5.4).
- Sticky headers and footers must not obscure focused elements (2.4.11).
- Test with VoiceOver (iOS) and TalkBack (Android). Swipe navigation order must match visual order.

## Responsive Design
- Mobile-first CSS; enhance at larger widths with container queries for components.
- Landscape phones: short viewport heights. Avoid tall fixed headers; allow scrolling within sheets.
- Foldables and tablets: bottom nav → side rail at ≥ ~600–840px widths.
- Test with large system font sizes: text should wrap, not truncate critical info.

## Performance
- Budget: aim for < ~170 KB compressed JS for initial route on mobile-critical pages; rely on Server Components to keep client JS minimal.
- INP ≤ 200ms at p75 on mobile: break long tasks, avoid heavy synchronous work in input handlers, use `useTransition` for non-urgent updates.
- Images: `next/image` with accurate `sizes` (mobile often `100vw`); avoid shipping desktop-sized images.
- Avoid scroll-linked JavaScript; use CSS scroll-driven animations or IntersectionObserver.
- Use passive event listeners for touch/scroll.
- Prefetch carefully on cellular: Next.js `<Link>` prefetches in viewport. Consider `prefetch={false}` for long lists of links on data-constrained contexts.

## Security
- Deep links and URL-driven overlay state: validate params; never open arbitrary URLs from query strings (open redirect).
- Clipboard and share: share only intended URLs; strip tokens from shared links.
- OTP autofill (`autocomplete="one-time-code"`) and WebOTP are fine. Never auto-submit payments on autofill.
- Treat mobile web sessions like desktop: httpOnly cookies, no tokens in localStorage.

## Testing
- Playwright device emulation (iPhone, Pixel) for layout and flows, plus real-device testing (BrowserStack/LambdaTest or device lab), since emulation misses keyboard and viewport behavior.
- Test matrix: iOS Safari latest-1, Android Chrome on a mid-tier device, Samsung Internet, landscape, keyboard open, 200% text.
- Back button tests: open sheet → Back closes sheet, not page.
- Field data: segment RUM by device class and connection type.

## Tooling
- CSS: native `dvh/svh/lvh` (Baseline widely available), `env()` safe-area insets.
- Sheets/drawers: Vaul (React bottom sheet), Radix Dialog–based sheets, React Aria Modal.
- Gestures (if needed): `@use-gesture/react`; always with button alternatives.
- Testing: Playwright devices, BrowserStack, Chrome remote debugging, Safari Web Inspector.
- RUM: `web-vitals` library, Vercel Speed Insights, or other RUM.

## Framework Notes
- **Next.js App Router (primary):**
  - `export const viewport: Viewport` in root layout, not a manual meta tag. Supports `viewportFit`, `interactiveWidget`, `themeColor`.
  - Intercepting + parallel routes for photo viewers or detail overlays with correct Back behavior and deep links.
  - `loading.tsx` for instant skeletons on navigation.
  - Server Components to minimize client JS; `next/dynamic` for heavy mobile-optional features (maps, editors).
  - URL state for sheets/filters via `useSearchParams` or nuqs.
- **React (Vite SPA):** add the viewport meta tag manually in `index.html`; use React Router or TanStack Router search params for overlay state; lazy-load routes to protect mobile startup time.

## AI Agent Guidance
- Never use `100vh` alone for full-height mobile layouts, never disable zoom, and never set input font below 16px.
- Every overlay that fills the screen must close on Back. Verify manually in a mobile emulator.
- Add safe-area padding to anything fixed at the top or bottom.
- Verify before done:
  - [ ] Viewport metadata set; no `user-scalable=no`
  - [ ] Layout correct with keyboard open (Chromium and Safari)
  - [ ] Touch targets ≥ 44px for primary controls
  - [ ] Back closes sheets/dialogs; deep links open them
  - [ ] Hover-only interactions have touch alternatives
  - [ ] Mobile INP/LCP within budget in lab test on throttled CPU

## Examples

```tsx
// Bottom navigation (Next.js)
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const items = [
  { href: "/", label: "Home", icon: HomeIcon },
  { href: "/search", label: "Search", icon: SearchIcon },
  { href: "/orders", label: "Orders", icon: BagIcon },
  { href: "/account", label: "Account", icon: UserIcon },
];

export function BottomNav() {
  const pathname = usePathname();
  return (
    <nav aria-label="Primary" className="bottom-nav">
      {items.map(({ href, label, icon: Icon }) => {
        const current = href === "/" ? pathname === "/" : pathname.startsWith(href);
        return (
          <Link key={href} href={href} aria-current={current ? "page" : undefined}>
            <Icon aria-hidden="true" /><span>{label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
```

```html
<!-- OTP field that autofills from SMS on iOS/Android -->
<label for="otp">Verification code</label>
<input id="otp" name="otp" inputmode="numeric" autocomplete="one-time-code" enterkeyhint="done" pattern="\d{6}" maxlength="6">
```

## Related Skills
- [progressive-web-apps](../progressive-web-apps/Skill.md) — installability, offline, push
- [responsive-design](../responsive-design/Skill.md) — breakpoint strategy
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — target size, gestures
- [drawers-and-sheets](../drawers-and-sheets/Skill.md) — bottom sheet component
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — nav patterns
- [inp-optimization](../inp-optimization/Skill.md) — mobile interactivity
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — mobile auth inputs
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — intercepting/parallel routes for overlays
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md) — device matrix

## Sources
- [HTMHell — Control viewport resize behavior with interactive-widget](https://www.htmhell.dev/adventcalendar/2024/4/) — Community — resizes-visual/resizes-content/overlays-content behavior
- [web.dev — Large, small, and dynamic viewport units](https://web.dev/blog/viewport-units) — Official — svh/lvh/dvh semantics
- [Next.js docs — generateViewport / viewport](https://nextjs.org/docs/app/api-reference/functions/generate-viewport) — Official — Viewport metadata API
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — 1.3.4, 1.4.10, 2.5.1, 2.5.7, 2.5.8, 2.4.11
- [Apple Human Interface Guidelines — layout and touch targets](https://developer.apple.com/design/human-interface-guidelines/layout) — Official — 44pt targets, safe areas
- [Google Search Central — intrusive interstitials guidance](https://developers.google.com/search/docs/appearance/avoid-intrusive-interstitials) — Official — mobile interstitial rules
- [MDN — VisualViewport](https://developer.mozilla.org/en-US/docs/Web/API/VisualViewport) — Official — keyboard offset handling

## License / Usage Notes
Summarized guidance; code original. Browser support statements are as of the Last Verified date and should be re-checked for Safari changes.

## Quality Tier
A — Grounded in official specs, WCAG, platform guidelines, and Next.js docs; Safari keyboard behavior remains partly empirical and version-dependent.

## Status
Active

## Last Verified
2026-09-15
