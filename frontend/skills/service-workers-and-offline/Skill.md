# Service Workers and Offline

## Summary
A service worker (SW) is a script that sits between the page and the network. It can cache assets, serve fallbacks offline, precache the app shell, handle push and background sync, and make repeat visits faster. It is also easy to get wrong: stale deploys, slow SW startup on navigations, caches that grow forever, and broken auth flows. For React and Next.js, use a maintained toolkit: Workbox via `vite-plugin-pwa` for Vite SPAs, and Serwist (`@serwist/next`) for Next.js. Apply conservative, per-route caching strategies.

## Category
Performance

## Subcategories
Service worker lifecycle, caching strategies, precaching, runtime caching, navigation preload, offline fallback, update flow, Workbox, Serwist, Static Routing API, Background Sync

## Problem It Solves
- Flaky or offline networks (field workers, travel, emerging markets).
- Slow repeat loads of app shells.
- Installable PWAs that need offline capability.
- Resilient uploads and forms that must survive connection loss.

## When To Use
- The app must work offline or on poor connectivity: field apps, POS, note taking, docs.
- A PWA install experience is required ([progressive-web-apps](../progressive-web-apps/Skill.md)).
- Repeat visits are frequent and the app shell is heavy (Vite SPA dashboards).
- Push notifications or background sync are needed.

## When Not To Use
- Content sites with good HTTP caching and no offline need. The SW adds complexity and startup cost for little gain.
- To fix first-visit performance. A SW only helps later visits.
- When the team can't commit to testing update and rollback flows.

## Core Principles
1. **Be conservative by default.** Precache only the versioned app shell and choose a runtime strategy per route type.
2. **Never cache-first HTML without a deliberate update plan.** Use network-first with timeout, or stale-while-revalidate with update prompts.
3. **Updates must be safe.** A new SW waits by default. Prompt the user or activate on the next navigation. Avoid a blind `skipWaiting` that swaps assets under a running page.
4. **Bound every cache.** Set expiration by entries and age. Handle quota errors.
5. **Have a kill switch.** Be able to ship a no-op SW that unregisters itself and clears caches.

## Best Practices
- Serve `sw.js` with `Cache-Control: no-cache` from the root scope (or set `Service-Worker-Allowed`).
- Enable navigation preload when using network-first navigations, so the SW boot doesn't delay the HTML request.
- Consider the Service Worker Static Routing API (Chromium) to bypass the SW for routes it doesn't handle. This avoids SW startup cost.
- Never cache authenticated API responses in shared caches without scoping per user. Clear caches on logout.
- Don't cache non-GET requests. Queue mutations with Background Sync (Chromium) or an IndexedDB outbox with retry on `online`.
- Offline fallback page: precache `/offline` and serve it for failed navigations.
- Show an "update available" UI and reload on user action ([toasts-and-notifications](../toasts-and-notifications/Skill.md)).
- Version cache names and delete old caches in `activate`.
- Test with DevTools > Application > Service workers ("Update on reload", "Offline", "Bypass for network").

## Implementation Guidance

### Strategy by request type
| Request | Strategy | Expiration |
|---|---|---|
| Hashed static assets (JS/CSS/fonts) | Precache (build manifest) or CacheFirst | Replaced per build |
| Images | CacheFirst with expiration | 60 entries / 30 days |
| HTML navigations | NetworkFirst (timeout 3 s) + offline fallback | Small, short-lived |
| Public API GET (non-critical freshness) | StaleWhileRevalidate | 50 entries / 1 day |
| Authenticated/personal API | NetworkOnly (or NetworkFirst with per-user cache + clear on logout) | Short |
| POST/PUT mutations | NetworkOnly + Background Sync queue | Retry ~24 h |
| Third-party analytics | NetworkOnly (don't cache) | n/a |

### React (Vite SPA): vite-plugin-pwa (Workbox)
```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'prompt',                       // show update UI instead of silent skipWaiting
      workbox: {
        globPatterns: ['**/*.{js,css,html,woff2,svg}'],
        navigateFallback: '/index.html',
        navigateFallbackDenylist: [/^\/api\//],
        runtimeCaching: [
          { urlPattern: ({ request }) => request.destination === 'image',
            handler: 'CacheFirst',
            options: { cacheName: 'images', expiration: { maxEntries: 60, maxAgeSeconds: 30 * 24 * 3600 } } },
          { urlPattern: ({ url }) => url.pathname.startsWith('/api/public/'),
            handler: 'StaleWhileRevalidate',
            options: { cacheName: 'public-api', expiration: { maxEntries: 50, maxAgeSeconds: 86400 } } },
        ],
      },
      manifest: { name: 'Field App', short_name: 'Field', theme_color: '#0f172a', icons: [/* ... */] },
    }),
  ],
});
```
```tsx
// src/components/UpdatePrompt.tsx
import { useRegisterSW } from 'virtual:pwa-register/react';

export function UpdatePrompt() {
  const { needRefresh: [needRefresh], updateServiceWorker } = useRegisterSW();
  if (!needRefresh) return null;
  return (
    <div role="status" className="toast">
      A new version is available.
      <button onClick={() => updateServiceWorker(true)}>Reload</button>
    </div>
  );
}
```

### Next.js: Serwist
```ts
// next.config.ts
import withSerwistInit from '@serwist/next';
const withSerwist = withSerwistInit({ swSrc: 'app/sw.ts', swDest: 'public/sw.js', disable: process.env.NODE_ENV === 'development' });
export default withSerwist({ /* next config */ });
```
```ts
// app/sw.ts
import { defaultCache } from '@serwist/next/worker';
import { Serwist, type PrecacheEntry } from 'serwist';

declare const self: ServiceWorkerGlobalScope & { __SW_MANIFEST: (PrecacheEntry | string)[] };

const serwist = new Serwist({
  precacheEntries: self.__SW_MANIFEST,
  skipWaiting: false,
  clientsClaim: true,
  navigationPreload: true,
  runtimeCaching: defaultCache,   // review defaults; exclude authenticated routes
  fallbacks: { entries: [{ url: '/~offline', matcher: ({ request }) => request.destination === 'document' }] },
});
serwist.addEventListeners();
```
App Router caveats:
- Client navigations fetch RSC payloads (requests with the `RSC` header or `_rsc` query), not HTML. Cache them only deliberately, since they are per-route and tied to the build.
- Dynamic, authenticated pages should be NetworkOnly.

### Kill switch
```js
// public/sw.js (emergency replacement)
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', async () => {
  for (const key of await caches.keys()) await caches.delete(key);
  await self.registration.unregister();
  for (const client of await self.clients.matchAll()) client.navigate(client.url);
});
```

## Recommended Workflow
1. Define requirements: offline scope (which routes and data), freshness per data type, and auth constraints.
2. Pick the toolkit (vite-plugin-pwa or Serwist). Draft the strategy table.
3. Implement the precache, runtime caching, offline fallback, and update prompt.
4. Test in DevTools: offline, slow 3G, update flow across two deploys, logout clearing caches, and quota (Application > Storage).
5. Measure: repeat-visit LCP, navigation timing with SW (check `workerStart` vs `fetchStart` in Navigation Timing), and SW startup cost.
6. Document and test the kill switch before launch.

## Patterns
- **App shell + network-first content.**
- **Offline outbox**: IndexedDB queue of mutations with retry and conflict handling ([optimistic-ui](../optimistic-ui/Skill.md)).
- **Update prompt**: waiting SW, toast, `SKIP_WAITING` message, reload.
- **Per-user cache namespace**, cleared on logout.

## Anti-Patterns
- **Cache-first HTML with `skipWaiting` on every deploy.** Mixed-version pages and broken chunks. Fix: network-first navigations plus prompt-based updates.
- **Caching authenticated API responses without scoping.** Data leaks between accounts on shared devices. Fix: NetworkOnly or per-user caches cleared on logout.
- **Unbounded runtime caches.** Quota errors and storage eviction. Fix: expiration plugins.
- **Registering the SW in development.** Confusing stale behavior. Fix: disable in dev.
- **A SW for every site "for performance."** Startup overhead on navigations with no benefit. Fix: only with a clear use case; navigation preload or static routing.
- **Using the unmaintained `next-pwa`.** Fix: Serwist.

## Accessibility
- Update and offline notifications must be announced (`role="status"`/live region) and keyboard operable ([live-regions-and-announcements](../live-regions-and-announcements/Skill.md)).
- The offline fallback page must be a real accessible page (heading, explanation, retry button).
- Don't auto-reload while the user is typing. Unexpected context changes fail SC 3.2.

## Responsive Design
- Offline-first matters most on mobile. Test on real devices with airplane mode and flaky connections.
- Storage quotas are smaller on low-end devices. Cap caches accordingly.

## Performance
- SW startup can add tens to hundreds of ms to navigations on cold starts. Navigation preload and the Static Routing API mitigate this.
- Precache size affects install time and storage. Keep the shell small.
- Returning visits with a precached shell can reach sub-second LCP even on slow networks.

## Security
- SWs require HTTPS (localhost is exempt) and are powerful: a compromised SW persists. Protect the `sw.js` path, apply CSP, and never import SW scripts from third-party CDNs without integrity controls.
- Scope SWs narrowly. Don't let user-uploaded content be served from paths that could register a SW.
- Clear caches and IndexedDB on logout. Don't store tokens in Cache Storage.

## Testing
- Playwright: `context.setOffline(true)`, then reload and navigate. Assert the offline fallback and cached routes.
- Update flow E2E: deploy version A, open, deploy B, assert the prompt and a successful reload.
- Unit tests for routing matchers (which URLs get which strategy).
- Lighthouse PWA checks were removed from Lighthouse's default categories, so verify installability in DevTools > Application instead.

## Tooling
- Workbox v7 (GoogleChrome; maintenance moved to Chrome's Aurora team): Active.
- vite-plugin-pwa (Workbox-based, React hooks via `virtual:pwa-register/react`): Active.
- Serwist (`@serwist/next`, Workbox fork, recommended for Next.js): Active.
- next-pwa: Unmaintained; avoid.
- Chrome DevTools Application panel: Active.

## Framework Notes
- **React (Vite SPA)**: best fit for SW app-shell caching. Hashed assets plus `navigateFallback` to `index.html` works cleanly. Use `registerType: 'prompt'` with a React update component.
- **Next.js**: use Serwist and be selective. Server-rendered, dynamic, and authenticated routes should mostly stay NetworkOnly. Precache static assets and an offline route. Be careful with RSC payload caching across deploys. PWA manifest via `app/manifest.ts` ([progressive-web-apps](../progressive-web-apps/Skill.md)).

## AI Agent Guidance
- Do: confirm there is an offline or repeat-visit requirement before adding a SW.
- Do: use vite-plugin-pwa or Serwist, prompt-based updates, bounded caches, and an offline fallback.
- Don't: cache authenticated or personalized responses, enable the SW in dev, or use `next-pwa`.
- Don't: set cache-first for HTML.
- Before declaring done: offline test passes for the intended routes, the update flow is tested across two builds, logout clears caches, `sw.js` is served with `no-cache`, and the kill-switch procedure is documented.

## Examples
```ts
// Clear per-user caches on logout (client)
export async function clearUserCaches() {
  const keys = await caches.keys();
  await Promise.all(keys.filter((k) => k.startsWith('user-')).map((k) => caches.delete(k)));
}
```

## Related Skills
- [progressive-web-apps](../progressive-web-apps/Skill.md): manifest, installability
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md): HTTP cache layer beneath the SW
- [optimistic-ui](../optimistic-ui/Skill.md): offline mutations UX
- [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md): mobile offline expectations
- [back-forward-cache](../back-forward-cache/Skill.md): complementary history caching
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md): token storage and logout

## Sources
- [MDN: Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API) (Official): lifecycle, scope
- [Chrome for Developers: Workbox](https://developer.chrome.com/docs/workbox) (Official): strategies, expiration, navigation preload
- [GoogleChrome/workbox](https://github.com/GoogleChrome/workbox) (Open Source): maintenance transfer to Aurora team, v7
- [Serwist docs](https://serwist.pages.dev/) (Open Source): Next.js integration
- [vite-plugin-pwa](https://vite-pwa-org.netlify.app/) (Open Source): Vite integration, React update hook
- [Chrome: Service Worker Static Routing API](https://developer.chrome.com/docs/web-platform/service-worker-static-routing) (Official): bypassing SW startup
- [web.dev: Service worker caching and HTTP caching](https://web.dev/articles/service-worker-caching-and-http-caching) (Official): layering

## License / Usage Notes
Workbox MIT, Serwist MIT, vite-plugin-pwa MIT. Summarized. Examples original and simplified; check each toolkit's current API before copying.

## Quality Tier
B: Solid official foundations. The Serwist and vite-plugin-pwa API snippets were not re-fetched for Sept 2026 and should be verified against current docs.

## Status
Active

## Last Verified
2026-09-15
