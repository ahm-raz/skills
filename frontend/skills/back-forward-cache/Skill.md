# Back/Forward Cache (bfcache)

## Summary
The back/forward cache (bfcache) keeps a complete in-memory snapshot of a page, including its JS heap, when the user navigates away. Pressing Back or Forward then restores the page instantly, with no network, no JS re-execution and no re-render. History navigations are a large share of all navigations, so bfcache eligibility is one of the cheapest big wins for CWV. In React and Next.js the work is to remove blockers, handle restores correctly, and debug with `notRestoredReasons`. Blockers include `unload` listeners (often from third parties), open connections and `window.opener`. Handling restores means refreshing stale data and restarting timers on `pageshow` when `persisted` is true.

## Category
Performance

## Subcategories
bfcache eligibility, pagehide/pageshow, unload deprecation, Cache-Control no-store, notRestoredReasons API, WebSocket/WebRTC blockers, stale state on restore, Next.js and SPA interaction

## Problem It Solves
Back navigations that reload the whole page. That means slow LCP, lost scroll position and form state, repeated API calls, and poor CWV on history navigations. Pages also restore with stale data (cart counts, auth state) when restore handling is missing.

## When To Use
- Any site with hard navigations: Next.js pages navigated via full loads, returning to the site from external pages, multi-zone apps, MPA marketing pages, Vite SPA entry documents.
- DevTools shows "Back/forward cache: not restored."
- RUM shows a low share of `back_forward` navigations restored (web-vitals `navigationType: 'back-forward-cache'`).

## When Not To Use
- Client-side route changes inside a Next.js App Router or React Router app. Those back navigations are handled by the router (Next's client router cache, scroll restoration), not bfcache.
- Pages that must never be restored from memory for security (e.g., after logout on shared kiosks). Use `no-store` plus cookie changes; Chrome evicts in that case.

## Core Principles
1. **Never use `unload`.** Use `pagehide` (or `visibilitychange`) for teardown and beacons.
2. **Close what blocks, reopen on restore:** WebSockets, WebRTC, WebTransport, open IndexedDB transactions.
3. **Treat `pageshow` with `persisted` true as "the page resumed".** Refresh time-sensitive data and restart timers.
4. **Use `no-store` only for truly sensitive pages.** Chrome now allows many `no-store` pages into bfcache with safeguards (3-minute limit, eviction on cookie change), but other browsers may not.
5. **Debug with data:** the DevTools bfcache tester and the `notRestoredReasons` API in RUM.

## Best Practices
- Audit third-party scripts for `unload` handlers. Chrome is deprecating `unload`, and a `Permissions-Policy: unload=()` header blocks it for your page and its iframes.
- Open popups with `rel="noopener"` (the default for `target="_blank"` in modern browsers), since a non-null `window.opener` blocks bfcache.
- Close real-time connections in `pagehide` and reconnect in `pageshow`.
- On restore: re-validate auth-sensitive UI (cart, notifications, logged-in header) and resume polling.
- Avoid `Cache-Control: no-store` on non-sensitive HTML. Use `no-cache` ([http-caching-and-cdn](../http-caching-and-cdn/Skill.md)).
- Track `notRestoredReasons` (Chrome 123+) in RUM for sampled back navigations, to find blockers you can't reproduce locally.
- Don't break analytics. Send page views on `pageshow` with `persisted` true when you want to count restores.

## Implementation Guidance

### Common blockers → fixes
| Blocker | Fix |
|---|---|
| `unload` listener (app or third party) | Replace with `pagehide`; add `Permissions-Policy: unload=()`; pressure vendors |
| Open WebSocket / WebRTC / WebTransport | Close on `pagehide`, reopen on `pageshow` |
| `window.opener` reference | `rel="noopener"`; don't rely on opener |
| `Cache-Control: no-store` (non-Chrome browsers, or Chrome safeguards not met) | Use `no-cache` unless the page is sensitive |
| In-progress IndexedDB transaction / held Web Locks | Finish or abort on `pagehide` |
| Page with `beforeunload` always registered | Register only while there are unsaved changes; remove after |
| Broadcast/shared workers in some cases | Check `notRestoredReasons` and test |

### React hook for restore handling
```tsx
'use client';
import { useEffect } from 'react';

export function usePageRestore(onRestore: () => void, onHide?: () => void) {
  useEffect(() => {
    const show = (e: PageTransitionEvent) => { if (e.persisted) onRestore(); };
    const hide = () => onHide?.();
    window.addEventListener('pageshow', show);
    window.addEventListener('pagehide', hide);
    return () => { window.removeEventListener('pageshow', show); window.removeEventListener('pagehide', hide); };
  }, [onRestore, onHide]);
}
```
React effects don't re-run on bfcache restore: the component tree was never unmounted. That's why restore logic must use `pageshow`.

### Real-time connection that stays bfcache-eligible
```tsx
'use client';
import { useCallback, useEffect, useRef } from 'react';
import { usePageRestore } from '@/hooks/use-page-restore';

export function useNotificationsSocket(url: string, onMessage: (data: unknown) => void) {
  const ws = useRef<WebSocket | null>(null);
  const connect = useCallback(() => {
    ws.current = new WebSocket(url);
    ws.current.onmessage = (e) => onMessage(JSON.parse(e.data));
  }, [url, onMessage]);
  const disconnect = useCallback(() => { ws.current?.close(); ws.current = null; }, []);

  useEffect(() => { connect(); return disconnect; }, [connect, disconnect]);
  usePageRestore(connect, disconnect);   // close on pagehide (enables bfcache), reconnect on restore
}
```

### Refresh stale data on restore (TanStack Query)
```tsx
'use client';
import { useQueryClient } from '@tanstack/react-query';
import { usePageRestore } from '@/hooks/use-page-restore';

export function RestoreRefetch() {
  const qc = useQueryClient();
  usePageRestore(() => { void qc.invalidateQueries({ queryKey: ['cart'] }); });
  return null;
}
```

### Unsaved-changes guard that doesn't permanently block bfcache
```tsx
useEffect(() => {
  if (!isDirty) return;
  const handler = (e: BeforeUnloadEvent) => { e.preventDefault(); };
  window.addEventListener('beforeunload', handler);
  return () => window.removeEventListener('beforeunload', handler);
}, [isDirty]);
```

### Collect notRestoredReasons in RUM
```ts
addEventListener('pageshow', () => {
  const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming & { notRestoredReasons?: unknown };
  if (nav?.type === 'back_forward' && nav.notRestoredReasons) {
    navigator.sendBeacon('/api/rum/bfcache', JSON.stringify(nav.notRestoredReasons)); // strip URLs/ids server-side
  }
}, { once: true });
```

### Blocking `unload` via header (Next.js)
```ts
// next.config.ts
import type { NextConfig } from 'next';
const nextConfig: NextConfig = {
  async headers() {
    return [{ source: '/:path*', headers: [{ key: 'Permissions-Policy', value: 'unload=()' }] }];
  },
};
export default nextConfig;
```
Test third-party tags first: some rely on `unload` for final beacons and should move to `pagehide`.

## Recommended Workflow
1. DevTools > Application > Back/forward cache > "Test back/forward cache" on key templates. Note the reasons: "Actionable", "Pending support" or "Browser/extension".
2. Fix actionable blockers from the table. Add the `unload` Permissions-Policy after checking third parties.
3. Add restore handling for stale data, connections and timers.
4. Add RUM: the web-vitals `navigationType` breakdown plus sampled `notRestoredReasons`.
5. Verify: back navigations restore in DevTools, and RUM restore rate for `back_forward` rises.
6. Regression guard: Playwright (Chromium) test that navigates away and back, then asserts `pageshow` fired with `persisted` true.

## Patterns
- **Pagehide teardown / pageshow resume** for sockets, polling and media.
- **Conditional beforeunload**, only while dirty.
- **Restore-aware data refresh** via query invalidation.
- **RUM reason aggregation** to prioritize blockers across real users.

## Anti-Patterns
- **`window.addEventListener('unload', sendAnalytics)`.** Blocks bfcache and is unreliable. Fix: `visibilitychange`/`pagehide` + `sendBeacon`.
- **Always-on `beforeunload` handlers.** Fix: register only when needed.
- **`no-store` on all HTML** "for freshness". Fix: `no-cache`; refresh on restore.
- **Assuming React effects re-run on Back.** They don't. Fix: `pageshow` with `persisted`.
- **Showing stale logged-in UI after logout on restore.** Fix: cookie-change eviction (Chrome) plus a `pageshow` auth check.

## Accessibility
- bfcache restores scroll position and form state, which helps everyone and especially users of assistive tech and keyboard navigation.
- On restore with refreshed data, announce significant changes politely (e.g., "Cart updated") without moving focus ([live-regions-and-announcements](../live-regions-and-announcements/Skill.md)).

## Responsive Design
- Mobile users rely heavily on Back gestures, so bfcache wins are largest on mobile. Test on Android Chrome and iOS Safari; both implement bfcache, with different rules.

## Performance
- A restored page shows instantly. web-vitals reports bfcache restores as a separate `navigationType` and resets metrics appropriately.
- Pages in bfcache consume memory. Browsers evict them under pressure and after timeouts (Chrome: typically 10 minutes; 3 minutes for `no-store` pages).

## Security
- Sensitive pages: keep `Cache-Control: no-store`. Chrome evicts cached `no-store` pages when cookies change, so logged-out users can't go Back to authenticated views. Verify logout clears or rotates cookies.
- Don't rely on bfcache ineligibility as a security control. Enforce auth server-side and re-check on `pageshow` for sensitive UI.

## Testing
- DevTools bfcache tester (manual).
- Playwright (Chromium): `page.goto(A)`, `page.goto(B)`, `page.goBack()`, then assert via a `window.__restored` flag set in a `pageshow` handler with `persisted` true.
- Lighthouse bfcache audit ("Page prevented back/forward cache restoration") in lab runs.

## Tooling
- Chrome DevTools Application > Back/forward cache tester: Active.
- `notRestoredReasons` API (Chromium 123+): Active.
- web-vitals (`navigationType: 'back-forward-cache'`, v6.2 fix for spurious CLS after restore): Active.
- Lighthouse bfcache audit: Active.

## Framework Notes
- **Next.js:**
  - In-app `<Link>` Back navigations are soft; the router restores from its cache.
  - bfcache applies to full document navigations: arriving from another site, hard reloads followed by Back, multi-zone and cross-app links, and `<a>` without `<Link>`.
  - Dynamic routes are sent with `no-store`-style headers by default. Chrome's no-store bfcache support helps, but Safari and Firefox may not restore them. Keep pages static or cached where possible.
  - Avoid `unload` in custom scripts and tags (`next/script` vendors).
- **React (Vite SPA):**
  - The SPA document itself is a bfcache candidate when users leave the app (e.g., to a payment provider) and come Back. That's very valuable, since it avoids re-booting the whole app.
  - Ensure no `unload` handlers, close sockets on `pagehide`, and refresh query data on restore.

## AI Agent Guidance
- Do: replace `unload` with `pagehide`/`visibilitychange`, make `beforeunload` conditional, and close sockets on `pagehide` with reconnect on `pageshow`.
- Do: add restore handling for stale, sensitive UI (cart, auth).
- Don't: add `Cache-Control: no-store` to non-sensitive pages, or assume React effects run on Back.
- Before declaring done: the DevTools bfcache test passes for the page (or the only remaining reasons are non-actionable), restore handling is verified manually, and there's no stale auth UI after logout followed by Back.

## Examples
```tsx
// Resume a countdown/poll after restore
usePageRestore(() => { startPolling(); }, () => { stopPolling(); });
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md): navigation types in field data
- [http-caching-and-cdn](../http-caching-and-cdn/Skill.md): no-store vs no-cache
- [speculation-rules-and-prerendering](../speculation-rules-and-prerendering/Skill.md): instant forward navigations
- [third-party-script-management](../third-party-script-management/Skill.md): vendor unload handlers
- [realtime-data-ui](../realtime-data-ui/Skill.md): socket lifecycle
- [javascript-memory-leaks](../javascript-memory-leaks/Skill.md): lifecycle discipline

## Sources
- [web.dev: Back/forward cache](https://web.dev/articles/bfcache) (Official): pageshow/pagehide, blockers, unload deprecation, testing
- [Chrome: bfcache for Cache-Control: no-store](https://developer.chrome.com/docs/web-platform/bfcache-ccns) (Official): 2025 rollout, 3-minute limit, cookie-change eviction
- [Chrome: notRestoredReasons API](https://developer.chrome.com/docs/web-platform/bfcache-notrestoredreasons) (Official): RUM diagnostics
- [Chrome: Deprecating the unload event](https://developer.chrome.com/docs/web-platform/deprecating-unload) (Official): Permissions-Policy unload
- [web-vitals changelog](https://github.com/GoogleChrome/web-vitals/blob/main/CHANGELOG.md) (Open Source): bfcache handling in v6
- [RUMvision: Chrome now ignores Cache-Control: no-store](https://www.rumvision.com/blog/chrome-now-ignores-cache-control-no-store-why-you-should-care/) (Community): field impact context

## License / Usage Notes
Summarized from web.dev and Chrome docs (CC BY). Examples original.

## Quality Tier
A: Official sources verified. Per-browser eligibility rules differ and change; retest periodically.

## Status
Active

## Last Verified
2026-09-15
