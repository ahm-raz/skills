# Accessible SPA Routing

## Summary
Making client-side navigation in Next.js (App Router) and React SPAs (React Router, TanStack Router) as perceivable as a full page load. On every route change: update the document title, announce the new page, move focus to a sensible starting point, and handle scroll, loading states, back/forward and modal routes. Next.js ships a built-in route announcer, but focus management is still your job.

## Category
Accessibility

## Subcategories
Route change announcements, document title, focus on navigation, scroll restoration, loading states, intercepting route modals, back/forward, hash links, Next.js route announcer

## Problem It Solves
On a full page load, screen readers announce the new title and start reading at the top. With client-side routing the URL changes silently, focus stays on the clicked link (which may no longer exist), and keyboard users must tab from wherever they were. Users don't know the page changed, or get lost. Relevant criteria: 2.4.2 Page Titled, 2.4.3 Focus Order, 4.1.3 Status Messages, 3.2.x.

## When To Use
- Any app with client-side navigation: Next.js `<Link>`/`router.push`, React Router, TanStack Router.
- Tab-like routes, wizard steps as routes, filter changes that update the URL, intercepted/parallel modal routes.

## When Not To Use
- Query-string-only updates that just filter the current view (e.g., `?sort=`) are not a new page. Announce the result count (live region) instead of moving focus.
- Full server navigations (MPA, `<a>` without client routing) are handled by the browser.

## Core Principles
1. **Every route has a unique, descriptive title** (2.4.2).
2. **Announce the navigation once.** Use the title or the main heading.
3. **Move focus to the start of the new content**, normally the `<h1>` (with `tabIndex={-1}`) or `<main>`, but not on the initial page load.
4. **Don't move focus for in-page state changes** (sort, filter, pagination that keeps context). Announce instead.
5. **Respect back/forward and hash navigation.** Restore scroll; focus hash targets.
6. **Loading is perceivable.** If navigation takes time, announce "Loading" and then the page.
7. **Modal routes behave like dialogs.** Focus in on open, restore to the trigger on close.

## Best Practices
- Research basis: Marcy Sutton's user testing with Fable (Gatsby, 2019) found that focusing a heading or a small "skip link"-style element at the top of new content, combined with an announcement, worked well. Resetting focus to `<body>` was disorienting.
- Pick one focus target strategy app-wide for consistency:
  - **H1 focus** (most common): `<h1 tabIndex={-1}>` receives focus, and screen readers read the heading.
  - **Main focus**: `<main tabIndex={-1}>`, which may read the entire main region in some screen readers (verbose).
  - **Top-of-page skip link focus**: focus the skip link, so the next Tab or Enter jumps to main.
- Hide the focus outline on programmatically focused non-interactive targets only if the heading is prominent (`h1:focus:not(:focus-visible) { outline: none }`). Keep keyboard focus visible.
- Titles: "Specific page – Section – Site". Prefix "Error: " on validation failures and "(3) " on unread counts carefully (announcement noise).
- Don't double-announce. With Next.js's announcer and focus on an H1, users may hear the title and then the heading; that's acceptable, and customising is optional.
- Scroll: new routes start at the top unless restoring history; hash routes scroll to and focus the target.

## Implementation Guidance

### Next.js App Router
- **Title.** `export const metadata = { title: 'Billing' }` or `generateMetadata` per page, with the template `%s | Acme` in the root layout.
- **Announcement.** Next.js includes a route announcer (a visually hidden `aria-live` region) that on client navigation reads `document.title`, falling back to the first `h1`, then the pathname. Ensure titles are meaningful. Don't build a second route announcer.
- **Focus.** Add a small client component in the root layout:

```tsx
// app/route-focus.tsx
'use client';
import { usePathname } from 'next/navigation';
import { useEffect, useRef } from 'react';

export function RouteFocus() {
  const pathname = usePathname();
  const first = useRef(true);

  useEffect(() => {
    if (first.current) { first.current = false; return; }  // don't steal focus on initial load
    if (window.location.hash) return;                          // let hash targets win
    // Wait a frame so the new page's content is committed
    const id = requestAnimationFrame(() => {
      const target = document.querySelector<HTMLElement>('main h1') ?? document.querySelector<HTMLElement>('main');
      if (!target) return;
      if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex', '-1');
      target.focus({ preventScroll: true });
    });
    return () => cancelAnimationFrame(id);
  }, [pathname]); // pathname only: search param changes don't move focus

  return null;
}
```
```tsx
// app/layout.tsx
<body>
  <a href="#main" className="skip-link">Skip to main content</a>
  <Header />
  <main id="main" tabIndex={-1}>{children}</main>
  <RouteFocus />
</body>
```
Notes:
- Streaming: if the page suspends, the H1 may not exist yet. Render the H1 outside Suspense boundaries (in the page shell) so it's available immediately, and put data-dependent parts inside Suspense.
- `loading.tsx`: include a heading or `role="status"` "Loading billing…" so users hear something during slow navigations.
- Intercepting routes (`@modal/(.)photo/[id]`): render a dialog (Radix/React Aria or native `dialog`). Opening focuses inside the dialog; closing with `router.back()` should restore focus to the originating `<Link>`. Store the trigger element id in state or a ref before navigation, and skip `RouteFocus` for modal segments (check `useSelectedLayoutSegment('modal')` or a flag).
- Layout-preserving navigations (tabs implemented as sibling routes under a shared layout): consider focusing the tab panel heading rather than the page H1. Keep focus on the tab if the route change mimics tab selection.

### React (Vite SPA) with React Router
```tsx
// RootLayout.tsx (React Router data/framework mode)
import { Outlet, ScrollRestoration, useLocation, useMatches } from 'react-router';

export function RootLayout() {
  const { pathname } = useLocation();
  const matches = useMatches() as { handle?: { title?: string } }[];
  const title = matches.at(-1)?.handle?.title;
  const [message, setMessage] = useState('');
  const first = useRef(true);

  useEffect(() => {
    if (title) document.title = `${title} | Acme`;
    if (first.current) { first.current = false; return; }
    setMessage(`${title ?? 'Page'} loaded`);               // announce
    requestAnimationFrame(() => document.querySelector<HTMLElement>('main h1')?.focus());
  }, [pathname, title]);

  return (
    <>
      <a href="#main" className="skip-link">Skip to main content</a>
      <Header />
      <main id="main" tabIndex={-1}><Outlet /></main>
      <p role="status" aria-atomic="true" className="sr-only">{message}</p>
      <ScrollRestoration />
    </>
  );
}
```
Page components render `<h1 tabIndex={-1}>`. With React 19 you can also render `<title>` inside route components (hoisted to head).

- **TanStack Router.** Subscribe via `useRouterState({ select: s => s.location.pathname })`, set titles from route `head()`/loader data, and use the same focus and announce effect. Enable `scrollRestoration`.

## Recommended Workflow
1. Define unique titles for all routes (metadata or route handles).
2. Choose the focus strategy (H1 recommended) and implement it once in the root layout.
3. Decide per navigation type: page change (focus plus announce), in-page state (announce only), modal route (dialog focus), hash (target focus).
4. Handle loading: accessible `loading.tsx`/Suspense fallback with status text.
5. Test with NVDA+Chrome and VoiceOver+Safari: click a nav link and hear the title or heading, then the next Tab goes into the page content. Test back/forward, hash links and modal routes.
6. Automate with Playwright: after navigation, assert the title and that the focused element is the H1.

## Patterns
- **H1-focus plus built-in announcer** (Next.js default stack).
- **Announcer plus H1 focus** (SPA).
- **Filter URL state.** `router.replace('?status=open', { scroll: false })` plus a result count in `role="status"`, with no focus move.
- **Wizard as routes.** Focus the step heading "Step 2 of 4: Payment" and update the title "Payment – Step 2 of 4 – Checkout".
- **Not-found / error routes.** A title "Page not found", H1 focus, and links back.

## Anti-Patterns
- **Same `<title>` for every route.** Screen readers announce nothing useful. Set per-route metadata.
- **Resetting focus to `document.body`.** Users land at the top with no context. Focus the H1 or main.
- **Moving focus on the initial load.** Skips the skip link, header and page context. Guard with a first-render ref.
- **Moving focus on every search param change.** Disrupts users while filtering. Scope to pathname.
- **Custom announcer duplicating Next.js's.** Double announcements. Rely on the built-in one plus good titles.
- **`scroll-behavior: smooth` on route changes.** Slow and disorienting. Instant scroll; smooth only when motion is allowed.
- **Modal routes without focus restoration.** After `router.back()`, focus lands on body. Restore to the trigger.
- **Focusing an H1 inside a Suspense boundary that hasn't resolved.** The focus call silently fails. Keep the H1 in the shell.

## Accessibility
- 2.4.2 Page Titled (A), 2.4.3 Focus Order (A), 4.1.3 Status Messages (AA), 3.2.1 On Focus / 3.2.2 On Input (A, no unexpected navigation), 2.4.1 Bypass Blocks (A), 2.4.11 Focus Not Obscured (AA: focus target not hidden under sticky header; set `scroll-padding-top`).

## Responsive Design
- On mobile, focusing the H1 moves the VoiceOver and TalkBack cursor there on most versions. Test on iOS Safari and Android Chrome, since behaviour varies.
- Collapsible mobile nav should close on navigation, and focus then goes to the new H1, not the closed menu button.

## Performance
- `requestAnimationFrame` focus adds no measurable cost. Avoid `setTimeout` delays longer than necessary.
- Prefetching (`<Link prefetch>`) makes navigations near-instant, reducing the need for loading announcements. Still handle slow networks.
- View Transitions on route change: ensure focus is moved after the transition's DOM update, not before, and respect reduced motion.

## Security
- Don't put sensitive data (names, account numbers) in `document.title`. Titles are exposed in history, tab titles and screen-share, and are announced aloud.

## Testing
```ts
// e2e/routing.spec.ts
import { test, expect } from '@playwright/test';

test('client navigation updates title and focuses H1', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('navigation', { name: 'Primary' }).getByRole('link', { name: 'Pricing' }).click();
  await expect(page).toHaveTitle(/^Pricing \| Acme$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Pricing' })).toBeFocused();
  await page.keyboard.press('Tab');
  // next focus should be inside main, not back in the header
  await expect(page.locator('main :focus')).toHaveCount(1);
});

test('filters do not move focus', async ({ page }) => {
  await page.goto('/invoices');
  const filter = page.getByRole('combobox', { name: 'Status' });
  await filter.selectOption('open');
  await expect(filter).toBeFocused();
  await expect(page.getByRole('status')).toHaveText(/\d+ invoices/);
});
```
- Manual: NVDA+Chrome and VoiceOver+Safari navigation passes; check the Next.js announcer output in Speech Viewer.

## Tooling
- Next.js built-in route announcer (App Router and Pages Router), `metadata` API.
- React Router `ScrollRestoration`, `useMatches` handles; TanStack Router `head`, `scrollRestoration`.
- Playwright `toHaveTitle`, `toBeFocused`; NVDA Speech Viewer.

## Framework Notes
- **Next.js (App Router).**
  - Built-in announcer plus `metadata` titles; add RouteFocus for focus.
  - Watch `loading.tsx`, streaming, intercepting/parallel routes, `redirect()` (the title updates at the final route), and `not-found.tsx`.
  - `router.refresh()` is not a navigation, so don't move focus.
- **Next.js Pages Router (legacy).** Also has a route announcer; use `router.events.on('routeChangeComplete')` for focus. Prefer migrating.
- **React (Vite SPA).** No built-in announcer. Implement title, announce and focus in the root layout route. React 19 `<title>` hoisting simplifies titles.

## AI Agent Guidance
- Do: give every route a unique title; add one app-wide route focus handler (pathname-scoped, skipping initial load and hash); ensure the H1 renders outside Suspense.
- Do: for SPAs without a built-in announcer, add a polite status announcement on route change.
- Don't: move focus on search-param changes or initial load, duplicate Next.js's announcer, or leave modal routes without focus restoration.
- Verify before done: Playwright test for title and H1 focus after client navigation; manual screen reader check noted.

## Examples
See Implementation Guidance (Next.js RouteFocus, React Router layout) and Testing.

## Related Skills
- [focus-management](../focus-management/Skill.md) — focus mechanics
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcements
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md) — skip links and main target
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — layouts and navigation
- [nextjs-advanced-routing](../nextjs-advanced-routing/Skill.md) — intercepting and parallel routes
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — titles
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — loading states
- [react-router-framework-mode](../react-router-framework-mode/Skill.md) — SPA routing
- [tanstack-router-and-start](../tanstack-router-and-start/Skill.md) — SPA routing

## Sources
- [Next.js docs: Accessibility (route announcements)](https://nextjs.org/docs/architecture/accessibility) — Official — built-in announcer behaviour (title, then h1, then pathname)
- [Marcy Sutton / Gatsby: What we learned from user testing of accessible client-side routing techniques (2019)](https://www.gatsbyjs.com/blog/2019-07-11-user-testing-accessible-client-routing/) — Community research — focus strategy evidence
- [Understanding 2.4.2 Page Titled / 2.4.3 Focus Order / 4.1.3 Status Messages](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — requirements
- [React Router docs (ScrollRestoration, useMatches)](https://reactrouter.com/) — Open Source — SPA APIs
- [Playwright assertions](https://playwright.dev/docs/test-assertions) — Open Source — toHaveTitle/toBeFocused

## License / Usage Notes
Summarised from framework docs (MIT) and W3C. Code is original.

## Quality Tier
A — well-established patterns with official Next.js announcer behaviour. Focus-target preferences vary among practitioners, and mobile screen reader behaviour should be verified per product.

## Status
Active

## Last Verified
2026-09-15
