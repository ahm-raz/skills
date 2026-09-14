# Progressive Web Apps

## Summary
How to make a React/Next.js web app installable and resilient as a Progressive Web App. It covers the Web App Manifest (via Next.js `app/manifest.ts`), install criteria and custom install UX, service worker strategy (caching, offline fallback, updates), web push notifications including iOS Home Screen web app constraints, app-like display modes, and when a PWA is or isn't the right choice versus native. Deep caching and service worker internals are in [service-workers-and-offline](../service-workers-and-offline/Skill.md).

## Category
Product Patterns

## Subcategories
Web App Manifest, installability, beforeinstallprompt, service workers, offline fallback, update flow, web push, iOS Home Screen web apps, display modes, app shortcuts, share target

## Problem It Solves
Teams "add PWA" by dropping in a plugin and end up with problems:
- Stale deployments stuck in a cache.
- Broken offline states.
- Nagging install prompts.
- Push that silently fails on iOS.
- Service workers that cache authenticated responses across users.

Platform support also differs: Chromium browsers fire `beforeinstallprompt`, while iOS Safari requires manual Add to Home Screen and restricts push to installed web apps. This skill gives a correct, minimal, maintainable approach.

## When To Use
- Apps used repeatedly (productivity, commerce reorders, field tools, messaging, content readers) where Home Screen presence, offline tolerance, or push add value.
- Replacing or complementing a thin native app.
- Internal/field apps needing offline data capture.

## When Not To Use
- One-off visit sites (campaign pages, most docs/blogs): the manifest may still help, but skip install UX and aggressive caching.
- Apps needing deep native capabilities unavailable on the web for your target platforms (e.g., background geolocation on iOS, some Bluetooth use cases on iOS): consider native or a hybrid.
- Mobile layout and viewport concerns: [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md).

## Core Principles
1. **Progressive.** The app works fully in a browser tab. Installation and offline support are enhancements.
2. **The manifest is the identity.** Stable `id`, `start_url`, `scope`, name, icons (192 and 512, plus maskable), and `display`.
3. **Cache deliberately.** Precache the app shell and static assets. Use runtime strategies per resource type. Never cache personalized/authenticated API responses in shared caches without per-user scoping and logout cleanup.
4. **Updates must be safe and visible.** Detect a new service worker and prompt "Update available" at a safe moment. Never leave users on stale code indefinitely.
5. **Ask for install and notifications in context.** Ask after the user has experienced value, triggered by a user gesture, and never on first load.
6. **Design for platform differences.** Custom install button on Chromium, instructional UI on iOS, push only after install on iOS.
7. **Offline is a designed state.** Show an offline page and cached content with freshness labels, and queue or disable actions clearly.

## Best Practices

### Manifest
- Required for Chromium installability: `name` or `short_name`, `icons` (192px and 512px), `start_url`, `display` (`standalone`, `fullscreen`, `minimal-ui`, or `window-controls-overlay`), and `prefer_related_applications` absent/false. Must be served over HTTPS.
- Also set `id` (stable app identity), `scope`, `theme_color`, `background_color`, `description`, `screenshots` (wide + narrow for richer install UI), `shortcuts`, `icons` with `purpose: "maskable"`.
- `start_url` should be a lightweight, cacheable route (e.g., `/app?source=pwa` for analytics). It must not require a fresh network round trip to render something.
- The W3C Web Application Manifest spec is still a Working Draft (republished January 2026) and browsers implement subsets, so check member support per browser.

### Install UX
- Chromium: capture `beforeinstallprompt`, call `preventDefault()`, show your own "Install app" button in a relevant place (settings, after a success moment), call `prompt()` on click, and track `userChoice` and `appinstalled`. Chrome also requires engagement heuristics (a click/tap and time on page) before the event fires.
- iOS/iPadOS Safari: no `beforeinstallprompt`. Show a dismissible hint ("Tap Share, then Add to Home Screen") only on iOS Safari, not in standalone mode, and not repeatedly. Recent iOS versions open Home Screen sites as web apps by default.
- Detect installed/standalone: `matchMedia("(display-mode: standalone)")` or `navigator.standalone` (iOS legacy).
- Don't show install prompts inside in-app browsers (Instagram, Facebook) where install isn't possible. Suggest "Open in browser" instead.

### Service worker
- Precache: built JS/CSS chunks (hashed), fonts, offline page, app icons.
- Runtime caching strategy by request type:

| Resource | Strategy |
|----------|----------|
| Hashed static assets (`/_next/static/*`) | Cache-first (immutable) |
| Images | Stale-while-revalidate with max entries/age |
| HTML navigations | Network-first with offline fallback page (short timeout) |
| Public API GETs | Stale-while-revalidate or network-first |
| Authenticated API responses | Network-only (default) or per-user cache cleared on logout |
| POST/PUT mutations | Network-only; optional Background Sync queue for safe, idempotent actions (Chromium only) |

- Scope the service worker at `/` served from `/sw.js` with `Cache-Control: no-cache` (so updates are found) and `Service-Worker-Allowed` only if needed.
- Version caches; delete old caches in `activate`.

### Updates
- On `updatefound` → new worker `installed` while an existing controller exists, show "A new version is available — Reload".
- On click, `postMessage({ type: "SKIP_WAITING" })` → worker calls `self.skipWaiting()` → page listens for `controllerchange` → `location.reload()`.
- Avoid auto-reloading while the user is mid-form.

### Push notifications
- Requires a service worker + Push API + VAPID keys (server keeps the private key).
- Request permission only from a user gesture, after explaining value ("Get notified when your order ships"). Offer granular categories.
- iOS/iPadOS 16.4+: push works only for web apps added to the Home Screen, and permission must come from a user gesture inside the installed app. Safari 18.4+ also supports Declarative Web Push, which doesn't require a service worker for display.
- Always provide in-app notification settings and honor unsubscribes. Handle `pushsubscriptionchange` and 404/410 responses from push services by deleting subscriptions.

## Implementation Guidance

### Manifest (Next.js)
```ts
// app/manifest.ts
import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/app",
    name: "Acme Orders",
    short_name: "Acme",
    description: "Track orders and reorder in two taps.",
    start_url: "/app?source=pwa",
    scope: "/",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#0f172a",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
    screenshots: [
      { src: "/screens/wide.png", sizes: "1280x720", type: "image/png", form_factor: "wide" },
      { src: "/screens/narrow.png", sizes: "750x1334", type: "image/png" },
    ],
    shortcuts: [{ name: "Reorder", url: "/app/reorder", icons: [{ src: "/icons/reorder-96.png", sizes: "96x96" }] }],
  };
}
```
Add `apple-touch-icon` via `app/apple-icon.png` for iOS Home Screen icons.

### Install button (Chromium) + iOS hint
```tsx
"use client";
import { useEffect, useState } from "react";

type BIPEvent = Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> };

export function InstallButton() {
  const [evt, setEvt] = useState<BIPEvent | null>(null);
  const [isIOS, setIsIOS] = useState(false);
  const [standalone, setStandalone] = useState(false);

  useEffect(() => {
    setStandalone(window.matchMedia("(display-mode: standalone)").matches);
    setIsIOS(/iphone|ipad|ipod/i.test(navigator.userAgent) && !("MSStream" in window));
    const onBIP = (e: Event) => { e.preventDefault(); setEvt(e as BIPEvent); };
    const onInstalled = () => setEvt(null);
    window.addEventListener("beforeinstallprompt", onBIP);
    window.addEventListener("appinstalled", onInstalled);
    return () => { window.removeEventListener("beforeinstallprompt", onBIP); window.removeEventListener("appinstalled", onInstalled); };
  }, []);

  if (standalone) return null;
  if (evt) return <button type="button" onClick={async () => { await evt.prompt(); await evt.userChoice; setEvt(null); }}>Install app</button>;
  if (isIOS) return <p className="hint">To install, tap <span aria-label="Share">Share</span> then “Add to Home Screen”.</p>;
  return null;
}
```

### Service worker options for Next.js
| Option | Notes |
|--------|-------|
| Hand-written `public/sw.js` (Next.js official PWA guide approach) | Full control; fine for offline page + push; you manage precache lists |
| Serwist (`@serwist/next`, successor to `next-pwa`) | Workbox-based precaching/runtime caching; check current compatibility with Turbopack builds (Next.js 16 default) before adopting |
| No service worker | Still installable in Chromium with a valid manifest; no offline/push |

```js
// public/sw.js — minimal: offline fallback + versioned cache + push
const VERSION = "v2026-09-15";
const OFFLINE_URL = "/offline";
self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll([OFFLINE_URL, "/icons/icon-192.png"])));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("message", (e) => { if (e.data?.type === "SKIP_WAITING") self.skipWaiting(); });
self.addEventListener("fetch", (e) => {
  if (e.request.mode === "navigate") {
    e.respondWith(fetch(e.request).catch(() => caches.match(OFFLINE_URL)));
  }
});
self.addEventListener("push", (e) => {
  const data = e.data?.json() ?? {};
  e.waitUntil(self.registration.showNotification(data.title ?? "Update", { body: data.body, icon: "/icons/icon-192.png", data: { url: data.url ?? "/app" } }));
});
self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  const url = new URL(e.notification.data?.url ?? "/app", self.location.origin); // same-origin only
  e.waitUntil(self.clients.openWindow(url.href));
});
```

Headers in `next.config.ts` for `/sw.js`: `Cache-Control: no-cache, no-store, must-revalidate` and `Content-Type: application/javascript; charset=utf-8`.

## Recommended Workflow
1. Decide goals: installability, offline (which screens?), push (which events?), and platform targets.
2. Add `app/manifest.ts`, icons (including maskable and apple-icon), and screenshots.
3. Add an offline page route and minimal service worker; register it client-side after load.
4. Implement update prompt flow.
5. Add install UX (Chromium button, iOS hint) in contextual locations.
6. Add push: server VAPID keys (env), subscription storage per user/device, permission UX, unsubscribe, settings.
7. Test in Chrome DevTools Application panel (manifest, SW, storage), Lighthouse, real iOS device installed web app, Android install.
8. Monitor: install events, SW errors, push delivery/opt-out rates.

## Patterns
- **Offline page with cached data:** "You're offline. Showing orders from 10:42 AM." Actions disabled with explanation.
- **Update toast:** persistent until acted upon; "Reload" button; not shown during critical flows.
- **Soft permission prompt:** in-app explainer card → user taps "Enable notifications" → native permission request.
- **Standalone-aware UI:** in `display-mode: standalone`, show in-app back button and share buttons since browser chrome is gone.
- **App shortcuts** for top tasks (manifest `shortcuts`).
- **Logout cleanup:** clear per-user caches, IndexedDB, and push subscription association.

## Anti-Patterns
- **Install or notification prompt on first visit.** Fix: contextual, after value, gesture-triggered.
- **Caching HTML cache-first.** Users stuck on old deployments whose chunks no longer exist. Fix: network-first navigations; hashed assets cache-first.
- **Caching authenticated API responses in shared cache.** Data leaks across users on shared devices. Fix: network-only or per-user cache cleared on logout.
- **`sw.js` served with long cache TTL.** Updates never detected. Fix: `no-cache` headers.
- **Auto `skipWaiting` + reload mid-task.** Lost user input. Fix: prompt-driven update.
- **Assuming push works on iOS in Safari tabs.** Fix: detect support; guide to install first.
- **Plugin-generated SW nobody understands.** Fix: document strategies; keep configuration explicit and tested.

## Accessibility
- Offline and update notices use polite live regions or visible banners with focusable actions (WCAG 4.1.3).
- In standalone display mode, provide in-app navigation (back, home) since browser controls are absent.
- Notification content must be meaningful without images; notification actions have text labels.
- Install hints and permission explainers must be dismissible and keyboard accessible, and must not trap focus.
- `theme_color` and splash colors: ensure contrast of any status-bar text.

## Responsive Design
- Screenshots in manifest for narrow and wide form factors.
- `display_override: ["window-controls-overlay"]` for desktop PWAs: use `env(titlebar-area-*)` to lay out the title bar region.
- Safe-area insets in standalone mode on iOS (`viewport-fit=cover`).

## Performance
- Precache only what's needed for first offline render. Over-precaching slows install and wastes storage.
- Register the service worker after `load` so it doesn't compete with initial rendering.
- Use navigation preload in the SW for network-first navigations to avoid SW startup latency.
- Watch storage quotas (`navigator.storage.estimate()`); request `persist()` for offline-critical apps.

## Security
- Service workers require HTTPS; scope them narrowly if hosting untrusted content on the same origin.
- VAPID private key only in server env; never in client bundles or the SW.
- Validate `notificationclick` URLs are same-origin to prevent open redirects.
- Push payloads: avoid sensitive data (lock screens display content). Send a minimal notice and fetch details after auth.
- Clear caches and IndexedDB on logout; consider `Clear-Site-Data: "cache", "storage"` header on logout response.
- CSP: `worker-src 'self'`.

## Testing
- Lighthouse PWA-related checks and Chrome DevTools Application panel (manifest warnings, SW lifecycle, offline simulation).
- Playwright: `context.setOffline(true)` to verify offline fallback; service worker interception enabled (`serviceWorkers: "allow"`).
- Update flow test: deploy v1, open, deploy v2, verify prompt and correct reload.
- Real devices: Android Chrome install + push; iOS Home Screen install + push permission from installed app.
- Logout test: cached per-user data removed.

## Tooling
- Next.js `app/manifest.ts`, `app/icon.png`, `app/apple-icon.png` metadata conventions.
- Serwist (active successor to next-pwa); Workbox (Google, underlying libraries).
- `web-push` (Node) for sending push with VAPID.
- PWABuilder (Microsoft) for manifest validation and store packaging (Microsoft Store, Google Play via Trusted Web Activity).
- Maskable icon editors (e.g., maskable.app).

## Framework Notes
- **Next.js App Router (primary):** `app/manifest.ts` generates `/manifest.webmanifest` and links it automatically. Register the SW in a small client component in the root layout. Add Server Actions for `subscribeUser`/`unsubscribeUser` that store subscriptions per session and call `web-push` server-side. Exclude `/sw.js` and `/manifest.webmanifest` from `proxy.ts` auth matchers. Static export (`output: "export"`) works for manifest and SW, but not for Server Actions push handling.
- **React (Vite SPA):** `vite-plugin-pwa` (Workbox-based) generates manifest and SW with update prompts (`registerType: "prompt"`). SPA navigations need a navigation fallback to `index.html` in the SW, and API routes must be excluded from that fallback.

## AI Agent Guidance
- Don't add a service worker unless offline, push, or performance goals are stated. A manifest alone is often enough for installability.
- Never cache authenticated responses in the SW by default; never auto-reload on update without user consent.
- Never commit VAPID private keys; reference env var names only.
- Verify before done:
  - [ ] Manifest valid in DevTools (icons 192/512 + maskable, id, start_url, display)
  - [ ] SW served with no-cache headers; update prompt works across deploys
  - [ ] Offline fallback renders for navigations
  - [ ] Install UX: Chromium button + iOS hint, hidden in standalone mode
  - [ ] Push permission requested only from user gesture; iOS only when installed
  - [ ] Logout clears caches and storage

## Examples

```tsx
// Service worker registration + update prompt (client component in root layout)
"use client";
import { useEffect, useState } from "react";

export function SWUpdater() {
  const [waiting, setWaiting] = useState<ServiceWorker | null>(null);
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    const onLoad = async () => {
      const reg = await navigator.serviceWorker.register("/sw.js", { scope: "/", updateViaCache: "none" });
      if (reg.waiting && navigator.serviceWorker.controller) setWaiting(reg.waiting);
      reg.addEventListener("updatefound", () => {
        const nw = reg.installing;
        nw?.addEventListener("statechange", () => { if (nw.state === "installed" && navigator.serviceWorker.controller) setWaiting(nw); });
      });
    };
    let reloaded = false;
    navigator.serviceWorker.addEventListener("controllerchange", () => { if (!reloaded) { reloaded = true; location.reload(); } });
    if (document.readyState === "complete") onLoad(); else window.addEventListener("load", onLoad, { once: true });
  }, []);
  if (!waiting) return null;
  return (
    <div role="status" className="update-banner">
      A new version is available.
      <button type="button" onClick={() => waiting.postMessage({ type: "SKIP_WAITING" })}>Reload</button>
    </div>
  );
}
```

## Related Skills
- [service-workers-and-offline](../service-workers-and-offline/Skill.md) — caching strategies in depth
- [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md) — viewport, touch, navigation
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — in-app notification UI
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md) — headers for SW and assets
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — Web Share, Badging, storage APIs
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — metadata file conventions
- [content-security-policy](../content-security-policy/Skill.md) — worker-src and script policies
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — permission prompt ethics

## Sources
- [web.dev — Installation criteria](https://web.dev/articles/install-criteria) — Official — Chromium manifest requirements, engagement heuristics, beforeinstallprompt
- [W3C — Web Application Manifest](https://www.w3.org/TR/appmanifest/) — Official (Working Draft) — manifest members, spec status
- [Next.js docs — manifest.json file convention and PWA guide](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/manifest) — Official — `app/manifest.ts`, SW + web-push guidance
- [firt.dev — iOS PWA compatibility notes](https://firt.dev/notes/pwa-ios/) — Community (expert-maintained) — iOS feature matrix
- [MagicBell — PWA iOS limitations (2026)](https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide) — Community — iOS 26 Home Screen default web app, push only for installed apps, Declarative Web Push in Safari 18.4
- [MDN — Service Worker API and Push API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API) — Official — lifecycle, update flow
- [Serwist](https://serwist.pages.dev/) — Open Source — Next.js SW integration (successor to next-pwa)

## License / Usage Notes
Summaries of public docs; code original. iOS behavior changes frequently; community sources used for iOS specifics should be re-verified on each iOS release.

## Quality Tier
A — Official Chromium, W3C, and Next.js sources plus expert-maintained iOS notes; iOS/EU platform behavior is volatile, preventing S.

## Status
Active

## Last Verified
2026-09-15
