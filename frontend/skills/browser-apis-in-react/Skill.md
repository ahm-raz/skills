# Browser APIs in React

## Summary
How to use browser APIs (IntersectionObserver, ResizeObserver, matchMedia, Clipboard, Web Storage, BroadcastChannel, online status, visibility, geolocation) from React and Next.js safely: wrapped in hooks, subscribed with `useSyncExternalStore` or effects with cleanup, SSR/hydration-safe, and permission-aware. Covers ref callbacks with cleanup (React 19) for element observers.

## Category
React

## Subcategories
Custom hooks, useSyncExternalStore, SSR safety, hydration, observers, storage, clipboard, cross-tab sync, permissions

## Problem It Solves
Direct `window`/`localStorage` access crashes during SSR, `typeof window` checks in render cause hydration mismatches, observers and listeners leak, and duplicated ad-hoc subscriptions re-render inefficiently. Standard hook patterns fix all of these.

## When To Use
- Reacting to viewport, element size/visibility, media queries, network, or page visibility.
- Persisting UI preferences to storage and syncing across tabs.
- Copy-to-clipboard buttons, share, or permission-gated APIs.
- Integrating any imperative browser API into declarative components.

## When Not To Use
- Layout that CSS can do: media queries, container queries, `prefers-color-scheme` styling (see [container-queries](../container-queries/Skill.md), [responsive-design](../responsive-design/Skill.md)).
- Server state/caching (use TanStack Query or Server Components).
- Heavy computations (see [web-workers-offloading](../web-workers-offloading/Skill.md)).

## Core Principles
1. Browser globals are unavailable during server rendering and prerendering; access them only in effects, event handlers, ref callbacks, or `useSyncExternalStore` `getSnapshot`.
2. Server HTML and the first client render must match. Use `getServerSnapshot` (stable fallback) instead of `typeof window` branches in render.
3. Every subscription, observer, listener, and timer needs cleanup.
4. External mutable sources (storage, media queries, online status) belong in `useSyncExternalStore`; element-bound observers belong in ref callbacks or effects.
5. Snapshots must be immutable/cached primitives or stable references; returning a new object each call loops forever.
6. Prefer CSS and HTML features over JS when they solve the problem (e.g., `loading="lazy"`, container queries, `:has()`).

## Best Practices
- Define `subscribe` and `getSnapshot` outside the component (or `useCallback` with deps) so identity is stable.
- Share one observer instance across many elements for lists (one IntersectionObserver with a Map of callbacks).
- Use React 19 ref callback cleanup: `ref={node => { const ro = new ResizeObserver(...); ro.observe(node); return () => ro.disconnect() }}`; memoize the callback if its deps change rarely (or rely on React Compiler).
- Wrap storage in try/catch: Safari private mode, quota errors, disabled storage, and JSON parse failures happen.
- Namespace and version storage keys (`app:v2:theme`).
- Listen to the `storage` event for cross-tab sync of `localStorage`; use `BroadcastChannel` for richer cross-tab messages (logout everywhere, cache invalidation).
- Clipboard: call `navigator.clipboard.writeText` only from a user gesture; handle rejection; show confirmation via a polite live region.
- Feature-detect (`'IntersectionObserver' in window`) inside effects if you support old environments.
- In Next.js, components using these hooks need `'use client'`; for components that cannot render meaningfully on the server, use `next/dynamic(..., { ssr: false })` from a Client Component.
- Consider a vetted hook library (`usehooks-ts`, `@uidotdev/usehooks`, `react-use` less maintained) but check SSR behavior of each hook.

## Implementation Guidance

### Which mechanism?
| API | Mechanism | Server snapshot |
|---|---|---|
| `matchMedia` | `useSyncExternalStore` | Sensible default (e.g., `false`) |
| `navigator.onLine` | `useSyncExternalStore` | `true` |
| `document.visibilityState` | `useSyncExternalStore` | `'visible'` |
| `localStorage` value | `useSyncExternalStore` (storage event + custom event) | `null`/default |
| Window size | `useSyncExternalStore` (throttled) — often avoid; prefer CSS/ResizeObserver | `undefined` |
| IntersectionObserver | Ref callback / effect | N/A (element-bound) |
| ResizeObserver | Ref callback / effect | N/A |
| Clipboard, Share, Geolocation | Event handler (user gesture) | N/A |
| BroadcastChannel | Effect with cleanup | N/A |

### Hydration-safe patterns
| Need | Wrong | Right |
|---|---|---|
| Show different UI on client | `if (typeof window !== 'undefined')` in render | `useSyncExternalStore` with server snapshot, or `useEffect` + state (`mounted`) |
| Theme from storage before paint | Read storage in component | Inline blocking script in `<head>` setting a class/attribute + `suppressHydrationWarning` on `<html>` |
| Date/time "now" | `new Date()` in render | Render on server with fixed value, update in effect; or client-only component |
| Browser-only library | Top-level import in shared component | `next/dynamic(() => import('./Map'), { ssr: false })` in a Client Component |

### useMediaQuery
```tsx
'use client'
import { useCallback, useSyncExternalStore } from 'react'

export function useMediaQuery(query: string, serverFallback = false): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const mql = window.matchMedia(query)
      mql.addEventListener('change', onChange)
      return () => mql.removeEventListener('change', onChange)
    },
    [query],
  )
  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia(query).matches,
    () => serverFallback,
  )
}

// usage: const prefersReducedMotion = useMediaQuery('(prefers-reduced-motion: reduce)')
```

### useLocalStorage with cross-tab sync
```tsx
'use client'
import { useCallback, useSyncExternalStore } from 'react'

const LOCAL_EVENT = 'local-storage'

function subscribe(onChange: () => void) {
  window.addEventListener('storage', onChange)      // other tabs
  window.addEventListener(LOCAL_EVENT, onChange)    // this tab
  return () => {
    window.removeEventListener('storage', onChange)
    window.removeEventListener(LOCAL_EVENT, onChange)
  }
}

export function useLocalStorage(key: string, initial: string) {
  const getSnapshot = () => {
    try { return window.localStorage.getItem(key) ?? initial } catch { return initial }
  }
  const value = useSyncExternalStore(subscribe, getSnapshot, () => initial) // string = stable snapshot

  const setValue = useCallback((next: string) => {
    try {
      window.localStorage.setItem(key, next)
      window.dispatchEvent(new Event(LOCAL_EVENT))
    } catch { /* quota or disabled storage: keep UI working */ }
  }, [key])

  return [value, setValue] as const
}
```
Store strings; parse JSON outside the snapshot (or cache parsed values by raw string) so `getSnapshot` never returns a fresh object.

### useInView (IntersectionObserver via ref callback)
```tsx
'use client'
import { useCallback, useState } from 'react'

export function useInView<T extends Element>(options?: IntersectionObserverInit & { once?: boolean }) {
  const [inView, setInView] = useState(false)
  const { root, rootMargin, threshold, once } = options ?? {}

  const ref = useCallback((node: T | null) => {
    if (!node) return
    const io = new IntersectionObserver(([entry]) => {
      setInView(entry.isIntersecting)
      if (entry.isIntersecting && once) io.disconnect()
    }, { root, rootMargin, threshold })
    io.observe(node)
    return () => io.disconnect() // React 19 ref cleanup
  }, [root, rootMargin, threshold, once])

  return [ref, inView] as const
}
```
Note: arrays for `threshold` must be memoized by the caller to keep the ref callback stable.

### useElementSize (ResizeObserver)
```tsx
'use client'
import { useCallback, useState } from 'react'

export function useElementSize<T extends HTMLElement>() {
  const [size, setSize] = useState<{ width: number; height: number } | null>(null)
  const ref = useCallback((node: T | null) => {
    if (!node) return
    const ro = new ResizeObserver(([entry]) => {
      const box = entry.borderBoxSize[0]
      setSize(prev =>
        prev && prev.width === box.inlineSize && prev.height === box.blockSize
          ? prev
          : { width: box.inlineSize, height: box.blockSize },
      )
    })
    ro.observe(node)
    return () => ro.disconnect()
  }, [])
  return [ref, size] as const
}
```

### Copy button
```tsx
'use client'
import { useState } from 'react'

export function CopyButton({ text }: { text: string }) {
  const [status, setStatus] = useState<'idle' | 'copied' | 'error'>('idle')
  async function copy() {
    try {
      await navigator.clipboard.writeText(text)
      setStatus('copied')
    } catch {
      setStatus('error')
    }
    setTimeout(() => setStatus('idle'), 2000)
  }
  return (
    <>
      <button type="button" onClick={copy}>Copy</button>
      <span role="status" className="sr-only">
        {status === 'copied' ? 'Copied to clipboard' : status === 'error' ? 'Copy failed' : ''}
      </span>
    </>
  )
}
```

### Cross-tab logout with BroadcastChannel
```tsx
'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export function AuthSync() {
  const router = useRouter()
  useEffect(() => {
    const bc = new BroadcastChannel('auth')
    bc.onmessage = (e: MessageEvent<{ type: 'logout' }>) => {
      if (e.data?.type === 'logout') router.replace('/login')
    }
    return () => bc.close()
  }, [router])
  return null
}
// on logout: new BroadcastChannel('auth').postMessage({ type: 'logout' })
```

## Recommended Workflow
1. Ask: can CSS/HTML solve it? If yes, stop.
2. Classify the API (global mutable source, element-bound, or gesture-triggered) using the table.
3. Write a hook with stable subscribe/snapshot or ref callback with cleanup.
4. Decide the server snapshot / fallback UI and ensure it matches the first client render.
5. Handle unsupported/permission-denied/error paths.
6. Test in `next build && next start` (hydration warnings show there), in private browsing, and with two tabs.

## Patterns
- **External store hook**: `useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)` for any browser state.
- **Ref-callback observer** with React 19 cleanup return.
- **Shared observer registry**: one `IntersectionObserver` + `WeakMap<Element, callback>` for long lists.
- **Blocking theme script** in root layout head for flash-free theme (see [dark-mode-implementation](../dark-mode-implementation/Skill.md)).
- **Client-only island**: `next/dynamic` `ssr: false` wrapper for libraries touching `window` at import time.
- **useEffectEvent** (React 19.2+) to read latest props inside long-lived listeners without resubscribing.

## Anti-Patterns
- **`typeof window !== 'undefined' ? A : B` in render.** Hydration mismatch. Fix: server snapshot or mounted effect.
- **Reading `localStorage` at module top level.** Crashes SSR/prerender. Fix: read inside snapshot/effect.
- **`getSnapshot` returning `JSON.parse(...)` or `{...}`.** Infinite re-render ("getSnapshot should be cached"). Fix: return primitive or cached reference.
- **Inline `subscribe` defined in component body without memoization.** Resubscribes every render. Fix: module-level or `useCallback`.
- **Scroll listeners for visibility/lazy loading.** Janky, main-thread heavy. Fix: IntersectionObserver or native `loading="lazy"`.
- **`window.resize` listener to switch layouts.** Re-renders on every pixel, SSR mismatch. Fix: CSS media/container queries; ResizeObserver for element-specific needs.
- **Forgetting `disconnect()`/`removeEventListener`.** Leaks and duplicate handlers under Strict Mode. Fix: always return cleanup.
- **`document.execCommand('copy')`.** Deprecated. Fix: async Clipboard API.
- **Storing tokens or PII in localStorage.** XSS-readable, persists on shared devices. Fix: httpOnly cookies; store only non-sensitive preferences.
- **Requesting geolocation/notifications on page load.** Users deny; browsers may auto-block. Fix: request in response to a clear user action.

## Accessibility
- Honor `prefers-reduced-motion` (prefer CSS; use `useMediaQuery` for JS animations) — WCAG 2.3.3; see [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md).
- Announce clipboard/share results via `role="status"` (WCAG 4.1.3 Status Messages).
- Infinite scroll via IntersectionObserver must also offer a keyboard-reachable "Load more" button and preserve focus.
- Do not change content based on viewport size in ways that remove functionality for zoomed users (WCAG 1.4.10 Reflow).

## Responsive Design
- Prefer CSS media and container queries; JS `useMediaQuery` only for behavior (e.g., render a drawer vs dialog component, or disable a heavy chart on small screens).
- Server fallback for `useMediaQuery` should match the mobile-first CSS default to avoid layout shift.
- ResizeObserver is the right tool for components that must compute layout from their own size (virtualized grids, canvas charts).

## Performance
- `useSyncExternalStore` only re-renders when the snapshot changes (`Object.is`); keep snapshots primitive.
- Throttle high-frequency sources (resize, scroll) inside `subscribe`, not in components.
- Batch observers; avoid one observer per list item.
- Avoid layout thrashing: read sizes from observer entries instead of calling `getBoundingClientRect` in loops.
- Storage access is synchronous; do not read large JSON on every render—cache by raw string.

## Security
- Never trust `localStorage`/`sessionStorage` content: validate/parse with a schema; it can be tampered with.
- Do not store secrets or auth tokens in Web Storage.
- Validate `MessageEvent` data from BroadcastChannel/`postMessage`; for `window.postMessage`, check `event.origin`.
- Clipboard reads (`readText`) require permission and a gesture; never read clipboard silently.
- Permissions-Policy headers can restrict powerful APIs (geolocation, camera) for third-party iframes.

## Testing
- Vitest + jsdom lacks IntersectionObserver/ResizeObserver/matchMedia: provide mocks in setup files and trigger callbacks manually.
- Test hooks with `renderHook` from Testing Library; simulate `storage` events with `window.dispatchEvent(new StorageEvent('storage', { key }))`.
- Test server snapshot by rendering with `renderToString` and asserting no browser API access.
- Playwright for real observers, clipboard (grant `clipboard-read/write` permissions), `emulateMedia({ reducedMotion: 'reduce' })`, multi-tab via multiple pages in one context.

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| `useSyncExternalStore` (React 18+) | Stable | Core primitive |
| Ref callback cleanup (React 19) | Stable | Element observers |
| `useEffectEvent` (React 19.2) | Stable | Latest values in listeners |
| `usehooks-ts` | Community, active | Check SSR options per hook |
| `react-intersection-observer` | Community, active | Mature `useInView` |
| `react-use` | Community, slower maintenance | Verify SSR safety |
| `document.execCommand` | Deprecated | Use Clipboard API |

## Framework Notes
- **Next.js**: Server Components cannot use these hooks; add `'use client'` to the hook module's consumers. Client Components still prerender on the server, so SSR safety rules apply. `next/dynamic` with `ssr: false` must be called from a Client Component. Hydration warnings are clearest in dev overlay; test prod builds too.
- **React (Vite SPA)**: no server render, so `typeof window` issues disappear, but the same hooks keep code portable if you later adopt SSR. Cleanup rules and Strict Mode double-invocation still apply.

## AI Agent Guidance
- Do: search the codebase for existing hooks (`useMediaQuery`, `useLocalStorage`) before adding new ones.
- Do: use `useSyncExternalStore` with a server snapshot for global browser state.
- Do: return cleanup from every effect and ref callback you write.
- Don't: access `window`, `document`, `navigator`, or storage outside effects/handlers/snapshots.
- Don't: add JS for something CSS handles.
- Before done: run a production build, load the page, and confirm no hydration mismatch warnings in the console; toggle Strict Mode behavior (dev) to confirm no duplicate listeners; test two tabs for sync features.

## Examples
```tsx
// Page visibility pause for polling
'use client'
import { useSyncExternalStore } from 'react'

const subscribe = (cb: () => void) => {
  document.addEventListener('visibilitychange', cb)
  return () => document.removeEventListener('visibilitychange', cb)
}
export const usePageVisible = () =>
  useSyncExternalStore(subscribe, () => document.visibilityState === 'visible', () => true)
```

```tsx
// Client-only map in Next.js
'use client'
import dynamic from 'next/dynamic'
const Map = dynamic(() => import('./leaflet-map'), { ssr: false, loading: () => <p>Loading map…</p> })
export function StoreLocator() { return <Map /> }
```

## Related Skills
- [react-custom-hooks-library-design](../react-custom-hooks-library-design/Skill.md) — designing reusable hooks
- [react-refs-and-imperative-apis](../react-refs-and-imperative-apis/Skill.md) — ref callbacks and cleanup
- [hydration-strategies](../hydration-strategies/Skill.md) — avoiding mismatches
- [javascript-memory-leaks](../javascript-memory-leaks/Skill.md) — listener and observer cleanup
- [list-virtualization](../list-virtualization/Skill.md) — observer-driven rendering
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — flash-free theme with storage
- [modern-javascript-for-react](../modern-javascript-for-react/Skill.md) — AbortController, closures

## Sources
- [react.dev: useSyncExternalStore](https://react.dev/reference/react/useSyncExternalStore) — Official — signature, server snapshot, caching caveats, online-status example
- [React 19 release post](https://react.dev/blog/2024/12/05/react-19) — Official — ref cleanup functions
- [Next.js SPA guide](https://nextjs.org/docs/app/guides/single-page-applications) — Official — browser-only components with next/dynamic ssr:false
- [MDN: Intersection Observer API](https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API) — Official — observer options/semantics
- [MDN: Clipboard API](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API) — Official — gesture/permission requirements
- [MDN: BroadcastChannel](https://developer.mozilla.org/en-US/docs/Web/API/BroadcastChannel) — Official — cross-tab messaging

## License / Usage Notes
react.dev CC-BY-4.0, MDN CC-BY-SA; code is original and illustrative. Summarized, not copied.

## Quality Tier
A — Core rules come from official React docs; hook implementations are standard community patterns verified against React 19 semantics.

## Status
Active

## Last Verified
2026-09-15
