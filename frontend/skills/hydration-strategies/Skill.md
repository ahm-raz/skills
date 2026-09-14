# Hydration Strategies

## Summary
Hydration is the client-side work React does to attach event handlers and state to server-rendered HTML. It downloads, parses and executes component code and re-runs render for every hydrated component, which is often the largest main-thread cost at load (hurting INP input delay and TBT). Strategies to reduce it in React + Next.js: render as much as possible as Server Components (zero hydration), push `'use client'` to leaves, use Suspense boundaries for selective/streaming hydration, defer non-critical client islands (`next/dynamic`, visibility/interaction triggers), avoid hydration mismatches, and consider Partial Prerendering / Cache Components for static shells.

## Category
Performance

## Subcategories
React Server Components, selective hydration, streaming SSR, Suspense, client boundaries, lazy hydration, hydration mismatches, Partial Prerendering, Activity

## Problem It Solves
SSR pages that paint quickly but are unresponsive for seconds ("uncanny valley"), large client bundles caused by hydrating static content, and hydration errors that force client re-rendering (layout shifts, flashes, lost performance).

## When To Use
- Next.js or SSR React (React Router framework mode) pages with high TBT/INP input delay during load.
- Large `'use client'` trees, providers wrapping the entire app with heavy imports.
- Hydration mismatch warnings in the console or client re-render fallbacks.

## When Not To Use
- Pure client-rendered Vite SPA with no SSR: there's no hydration—focus on [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) and [bundle-optimization](../bundle-optimization/Skill.md).
- Fully static content with no interactivity: ship no client JS at all.

## Core Principles
1. **The cheapest hydration is none**: Server Components render on the server and send no component JS.
2. **Client boundaries at leaves**: interactivity islands (buttons, forms, menus) as small Client Components receiving serializable props; server content passed as `children`.
3. **Suspense splits hydration**: React 18+ hydrates Suspense boundaries independently and prioritizes the ones the user interacts with (selective hydration).
4. **Defer what isn't needed at first interaction**: below-the-fold widgets load/hydrate on visibility or intent.
5. **Server and client first render must match**: mismatches make React discard and client-render the subtree.

## Best Practices
- Audit `'use client'` files: each is an entry to the client graph; everything it imports becomes client JS.
- Pass Server Components as `children`/props into Client Components instead of importing them inside client files.
- Wrap independent, slow or heavy regions (reviews, recommendations, comments) in `<Suspense>` so they stream and hydrate separately.
- Keep context providers in a thin `providers.tsx` Client Component; providers don't make their `children` client components.
- Read browser-only values (window size, `localStorage`, time zone) after hydration via `useSyncExternalStore` (with `getServerSnapshot`) or effects, and reserve space to avoid CLS.
- Format dates/numbers deterministically (explicit locale and time zone) on server and client to avoid mismatches.
- Use `suppressHydrationWarning` only for intentional single-node differences (e.g., timestamps, theme class on `<html>`).
- Heavy third-party client libraries (charts, maps, editors): `next/dynamic` with a skeleton, triggered on visibility or interaction.
- React 19.2 `<Activity mode="hidden">` keeps state for hidden UI (tabs, back-navigated views) while deprioritizing its rendering—use for pre-rendering likely-next UI without blocking visible work.

## Implementation Guidance

### Decision table
| Component needs | Render as | Hydration cost |
|---|---|---|
| Only data + markup | Server Component | None |
| Small interaction (toggle, like, copy) | Leaf Client Component | Small |
| Interaction but below fold / rarely used | Client Component via `next/dynamic` on visibility/interaction | Deferred |
| Browser-only lib (canvas, maps) | `next/dynamic(..., { ssr: false })` inside a Client Component | Deferred, no SSR HTML (reserve space) |
| Shared state across page | Provider at the smallest common subtree, not root | Proportional to subtree |
| Personalized part of static page | Static shell + streamed dynamic hole (Suspense / PPR) | Only the hole |

### Server content through client wrappers
```tsx
// app/product/[id]/page.tsx — Server Component
import { Tabs } from './tabs';              // 'use client'
import { Specs } from './specs';            // server
import { Reviews } from './reviews';        // server, slow data

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return (
    <Tabs
      specs={<Specs id={id} />}            // rendered on server, passed as props: not hydrated as component code
      reviews={
        <Suspense fallback={<ReviewsSkeleton />}>
          <Reviews id={id} />
        </Suspense>
      }
    />
  );
}
```
```tsx
// app/product/[id]/tabs.tsx
'use client';
import { useState, type ReactNode } from 'react';
export function Tabs({ specs, reviews }: { specs: ReactNode; reviews: ReactNode }) {
  const [tab, setTab] = useState<'specs' | 'reviews'>('specs');
  return (
    <div>
      <div role="tablist">
        <button role="tab" aria-selected={tab === 'specs'} onClick={() => setTab('specs')}>Specs</button>
        <button role="tab" aria-selected={tab === 'reviews'} onClick={() => setTab('reviews')}>Reviews</button>
      </div>
      <div role="tabpanel">{tab === 'specs' ? specs : reviews}</div>
    </div>
  );
}
```

### Mismatch-safe browser values
```tsx
'use client';
import { useSyncExternalStore } from 'react';

const subscribe = (cb: () => void) => { window.addEventListener('resize', cb); return () => window.removeEventListener('resize', cb); };
export function useIsWide() {
  return useSyncExternalStore(subscribe, () => window.innerWidth >= 1024, () => false /* server snapshot */);
}
```

### Defer hydration of a below-the-fold island (visibility)
```tsx
'use client';
import dynamic from 'next/dynamic';
import { WhenVisible } from '@/components/when-visible'; // IntersectionObserver wrapper

const Comments = dynamic(() => import('./comments'), { loading: () => <CommentsSkeleton /> });

export function LazyComments({ postId }: { postId: string }) {
  return <WhenVisible fallback={<CommentsSkeleton />}><Comments postId={postId} /></WhenVisible>;
}
```
Note: React has no built-in "hydrate on visible" for SSR HTML; this pattern skips SSR for the island (server renders the skeleton). Use it for content that isn't needed for SEO/LCP.

### Common mismatch causes → fixes
| Cause | Fix |
|---|---|
| `Date.now()`, `Math.random()` in render | Generate on server and pass as prop; or effect after mount |
| `typeof window !== 'undefined'` branches in render | `useSyncExternalStore` with server snapshot, or effect |
| Locale/time zone formatting differences | Explicit `locale` + `timeZone` in `Intl` |
| Invalid HTML nesting (`<div>` in `<p>`, nested `<a>`) | Fix markup (browser parser rewrites DOM) |
| Browser extensions injecting attributes | Usually safe to ignore; `suppressHydrationWarning` on `<html>/<body>` only if needed |
| Theme class set by inline script before hydration | `suppressHydrationWarning` on `<html>` (next-themes pattern) |

## Recommended Workflow
1. Record a load trace (4× CPU): measure hydration long tasks (React performance tracks show "Scheduler"/"Components"), TBT, and interact during load to see input delay.
2. Use Next.js analyzer to list client modules per route; find `'use client'` roots high in the tree.
3. Move static parts to Server Components; pass server-rendered content as `children`.
4. Add Suspense boundaries around slow/heavy regions; defer below-the-fold islands.
5. Fix all hydration mismatch warnings (dev overlay lists them).
6. Re-trace: hydration tasks shorter/split; first-load JS down; INP during load improved; no CLS introduced.

## Patterns
- **Islands via Server Components**: server page with small client islands.
- **Donut pattern**: Client Component wrapper with server `children` hole.
- **Streaming shell**: `loading.tsx`/Suspense fallbacks paint immediately; content streams and hydrates per boundary.
- **Static shell + dynamic holes**: Partial Prerendering / Cache Components in Next.js 16 (prerendered static shell, dynamic parts streamed) — see [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md).
- **Intent-triggered hydration**: load the island's code on hover/focus, render on click.

## Anti-Patterns
- **`'use client'` in root layout or page** → entire route hydrated. Fix: leaf boundaries.
- **Global providers importing heavy SDKs** (analytics, feature flags, i18n catalogs) at root. Fix: lazy-init SDKs, scope providers, load catalogs per route.
- **`ssr: false` for SEO/LCP content** → blank HTML, slower LCP. Fix: SSR it; defer only non-critical.
- **Blanket `suppressHydrationWarning`** hiding real bugs. Fix: fix causes; suppress only intentional nodes.
- **`useEffect(() => setMounted(true))` gating whole pages** → double render, flash, CLS. Fix: `useSyncExternalStore` or CSS-based responsive rendering.
- **Serializing huge props** into client islands → RSC payload bloat. Fix: pass IDs/minimal fields.

## Accessibility
- Before hydration, SSR HTML must be usable: links work, forms submit (progressive enhancement with Server Actions `<form action>`) ([progressive-enhancement](../progressive-enhancement/Skill.md)).
- Deferred islands need accessible placeholders; don't render interactive-looking controls that do nothing until hydrated—disable or use native fallbacks.
- Hydration must not reset focus or scroll position.

## Responsive Design
- Don't branch markup on viewport in render (mismatch); use CSS media/container queries for layout and `useSyncExternalStore` only for behavior.
- Lower-end mobile devices feel hydration cost most—profile with CPU throttling and on real devices.

## Performance
- Hydration cost ≈ client component code size + render work; both shrink with Server Components.
- Suspense boundaries let React yield between hydration chunks, improving input responsiveness during load.
- RSC payload for server content is still parsed; keep it lean.

## Security
- Props passed to Client Components are serialized into HTML; never pass secrets or full user records ([react-server-components](../react-server-components/Skill.md)).
- Use `import 'server-only'` on data-access modules to prevent client inclusion.

## Testing
- Playwright: fail tests on console errors containing hydration mismatch messages.
- Lab: TBT and "interaction during load" INP checks in Lighthouse user flows.
- E2E with JS disabled for critical forms/links (progressive enhancement smoke test).

## Tooling
- React 19 / 19.2 (`<Activity>`, performance tracks in Chrome DevTools) — Active.
- Next.js 16 App Router (Server Components, streaming, Cache Components/PPR) — Active.
- Next.js Bundle Analyzer (`next experimental-analyze`) — Experimental.
- React DevTools (component highlighting, Profiler) — Active.

## Framework Notes
- **Next.js**: primary lever is the server/client boundary; see [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) and [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md). Route-level strategy in [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**: no hydration unless you add SSR (React Router framework mode / TanStack Start). For CSR, the equivalent cost is initial mount—reduce with route splitting and lazy widgets. If you adopt SSR, the same boundary/Suspense rules apply ([react-router-framework-mode](../react-router-framework-mode/Skill.md)).

## AI Agent Guidance
- Do: default new components to Server Components in Next.js; add `'use client'` only where state/effects/browser APIs are needed, at the lowest level.
- Do: wrap slow data regions in Suspense with size-matched fallbacks.
- Don't: add `'use client'` to layouts/pages to "fix" an error—extract the interactive part instead.
- Don't: silence hydration warnings globally.
- Before declaring done: no hydration warnings in console, client module list for the route shrank or stayed flat, load trace shows no new long hydration tasks, SSR HTML still contains primary content.

## Examples
```tsx
// app/providers.tsx — thin client boundary
'use client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';

export function Providers({ children }: { children: ReactNode }) {
  const [client] = useState(() => new QueryClient());
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>; // children stay server-rendered
}
```

## Related Skills
- [react-server-components](../react-server-components/Skill.md) — server/client model
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — SSG/SSR/PPR choices
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — Suspense streaming
- [inp-optimization](../inp-optimization/Skill.md) — load-time input delay
- [bundle-optimization](../bundle-optimization/Skill.md) — client JS size
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — deferring islands
- [progressive-enhancement](../progressive-enhancement/Skill.md) — pre-hydration usability

## Sources
- [React: hydrateRoot](https://react.dev/reference/react-dom/client/hydrateRoot) — Official — hydration semantics, mismatch handling
- [React: Suspense](https://react.dev/reference/react/Suspense) — Official — streaming & selective hydration
- [React 19.2 release](https://react.dev/blog/2025/10/01/react-19-2) — Official — Activity, performance tracks
- [Next.js: Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components) — Official — boundaries, children pattern
- [Patterns.dev: Rendering patterns (islands, progressive hydration)](https://www.patterns.dev/) — Community — conceptual background
- [Next.js: Optimizing package bundling](https://nextjs.org/docs/app/guides/package-bundling) — Official — moving heavy work to Server Components

## License / Usage Notes
Summarized from React/Next.js docs (MIT/CC BY). Examples original.

## Quality Tier
A — Official model and verified APIs; "lazy hydration" guidance is a pattern (no first-party React API).

## Status
Active

## Last Verified
2026-09-15
