# Third-Party Script Management

## Summary
Third-party scripts often dominate main-thread time and hurt INP input delay, LCP, CLS and privacy. Typical examples are analytics, tag managers, A/B testing, consent managers, chat widgets, ads, embeds, session replay and social pixels. Managing them involves six things:
- Inventory and cost measurement.
- Governance: who may add tags, with what budget.
- Loading strategy: `next/script` strategies, facades, interaction-triggered loading, server-side tagging.
- Isolation: iframes, workers via Partytown, used with care.
- Security: CSP, SRI.
- Continuous monitoring with LoAF attribution.

## Category
Performance

## Subcategories
Tag managers, next/script strategies, @next/third-parties, facades, consent-gated loading, Partytown, server-side tagging, LoAF attribution, CSP/SRI, embeds, A/B testing scripts

## Problem It Solves
Marketing and product tags are added outside engineering review. Each one adds long tasks, network contention, cookies, and occasionally layout shifts or broken pages. They are among the most common causes of poor field INP. Many originate outside the app's bundle, so bundle tools don't see them.

## When To Use
- Adding or auditing analytics, tag managers, chat, ads, embeds, pixels or A/B tools.
- INP input delay is high, and LoAF/DevTools attribution points to third-party origins.
- Implementing consent management.

## When Not To Use
- First-party code splitting: see [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md).
- Choosing an experimentation platform's product features: see [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md).

## Core Principles
1. **Every tag has an owner, a purpose, a budget and a review date.** Remove tags that lack one.
2. **Nothing third-party is render-blocking.** Nothing loads before LCP unless it's legally required (consent) or truly critical.
3. **Load on the latest acceptable trigger:** idle, interaction, visibility, or consent.
4. **Prefer server-side or first-party alternatives:** server-side tagging, first-party analytics endpoints, static embeds and facades.
5. **Measure in the field.** Lab tests often miss tags that load after consent or on interaction.

## Best Practices
- Keep a tag inventory with fields: name, owner, origin(s), purpose, consent category, loading strategy, size, main-thread cost, review date.
- Next.js: use `next/script` and choose the strategy deliberately:
  - `beforeInteractive`: root layout only. Reserve it for bot detection or a consent manager.
  - `afterInteractive` (default): tag managers and analytics that must capture early page views.
  - `lazyOnload`: chat, social widgets, feedback tools.
- `@next/third-parties` offers optimized wrappers (`GoogleTagManager`, `GoogleAnalytics`, `YouTubeEmbed`, `GoogleMapsEmbed`). It's experimental, so check your version.
- Use facades for heavy embeds (YouTube, Vimeo, maps, chat): show a static preview and load the real thing on click.
- Gate on consent. Don't load non-essential tags until consent is given, which also improves performance for users who decline ([ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md)).
- Move client-side tag managers toward server-side tagging (e.g., GTM server container, Cloudflare Zaraz, a first-party collection endpoint).
- Avoid client-side A/B testing anti-flicker snippets. Run experiments at the edge or on the server ([feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md)).
- Self-host small, stable libraries instead of loading them from public CDNs. It avoids connection setup and supply-chain drift.
- Reserve space for embeds and ads ([cls-prevention](../cls-prevention/Skill.md)).
- Monitor LoAF `scripts[].sourceURL` by origin in RUM, and alert when a vendor's blocking time grows.

## Implementation Guidance

### Strategy decision table
| Tag type | Strategy | Notes |
|---|---|---|
| Consent manager (CMP) | `beforeInteractive` or inline minimal stub; banner as overlay | Must not cause CLS; keep light |
| Tag manager / analytics | `afterInteractive` (or `@next/third-parties` GTM/GA); consent-gated | Audit container contents regularly |
| Session replay / heatmaps | `lazyOnload` + sampling + consent | Heavy; sample 1–10% |
| Chat widget | Facade button → load on click (or `lazyOnload`) | Big INP win |
| YouTube/Vimeo | Facade (`YouTubeEmbed` / lite embed) | Loads ~0 KB until click |
| Maps | Static map image → interactive on click | |
| Ads | Async, reserved slots, lazy for below-fold slots | Coordinate with ad ops |
| A/B testing | Server/edge-side | Avoid anti-flicker |
| Social share buttons | Plain links (`https://twitter.com/intent/...`) | No SDK needed |
| Partytown candidate (simple analytics pixels) | `worker` offload after testing | Beta; not all scripts work |

### Next.js examples
```tsx
// app/layout.tsx
import Script from 'next/script';
import { GoogleTagManager } from '@next/third-parties/google';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        {children}
        {/* Consent-aware loading is usually handled inside GTM consent mode or by rendering conditionally */}
        <GoogleTagManager gtmId={process.env.NEXT_PUBLIC_GTM_ID!} />
        <Script src="https://widget.example-chat.com/loader.js" strategy="lazyOnload" />
      </body>
    </html>
  );
}
```

```tsx
// Consent-gated script (Client Component)
'use client';
import Script from 'next/script';
import { useConsent } from '@/lib/consent';

export function MarketingPixels() {
  const { marketing } = useConsent();
  if (!marketing) return null;
  return <Script id="pixel" src="https://pixel.example.com/p.js" strategy="lazyOnload" />;
}
```

```tsx
// Chat facade
'use client';
import { useState } from 'react';
import Script from 'next/script';

export function ChatFacade() {
  const [load, setLoad] = useState(false);
  const [ready, setReady] = useState(false);
  return (
    <>
      {!ready && (
        <button className="fixed bottom-4 right-4 rounded-full px-4 py-3" aria-label="Open chat"
                onClick={() => setLoad(true)} onPointerEnter={() => setLoad(true)}>
          {load ? 'Loading chat…' : 'Chat with us'}
        </button>
      )}
      {load && (
        <Script src="https://widget.example-chat.com/loader.js" strategy="afterInteractive"
                onReady={() => { setReady(true); window.ExampleChat?.open(); }} />
      )}
    </>
  );
}
```
`window.ExampleChat` stands in for the vendor's API. Declare its type in a `.d.ts` file.

```tsx
// YouTube facade via @next/third-parties
import { YouTubeEmbed } from '@next/third-parties/google';
<YouTubeEmbed videoid="dQw4w9WgXcQ" height={400} params="controls=1" />
```

### React (Vite SPA)
```tsx
// Load a script on idle/interaction without a framework helper
export function loadScript(src: string, attrs: Record<string, string> = {}) {
  return new Promise<void>((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const s = Object.assign(document.createElement('script'), { src, async: true });
    Object.entries(attrs).forEach(([k, v]) => s.setAttribute(k, v));
    s.onload = () => resolve(); s.onerror = reject;
    document.head.append(s);
  });
}
// usage: requestIdleCallback?.(() => loadScript('https://analytics.example.com/a.js')) ?? setTimeout(..., 2000)
```

### Measuring vendor cost
1. DevTools Performance: record a load and a typical interaction. The "3rd parties" insight lists transfer size and main-thread time by entity. Use "Dim 3rd parties" to see what's first-party.
2. Network request blocking: block a vendor's domain, re-record, and compare LCP/TBT/INP. That's the vendor's marginal cost.
3. Field: LoAF attribution grouped by `sourceURL` origin ([inp-optimization](../inp-optimization/Skill.md)).
4. WebPageTest: run the same test with and without the tag (block domains) to get a filmstrip comparison.

## Recommended Workflow
1. Build the inventory from production: DevTools network by domain, the tag manager container export, and a CSP report-only log of script origins.
2. Measure each tag's cost with domain blocking and the 3rd-party insight. Record it in the inventory.
3. Remove unused or duplicate tags. Mark each remaining tag with a strategy from the table.
4. Implement facades, consent gating, and lazy strategies. Move experiments server-side.
5. Add CSP allowlists and SRI where the vendor provides versioned files.
6. Govern: a PR or request process for new tags with a budget (e.g., ≤ 50 ms main-thread at p75 lab, ≤ 30 KB). Review quarterly.
7. Monitor LoAF by vendor in RUM and alert on regressions.

## Patterns
- **Facade/lite embed** for video, maps and chat.
- **Consent-first loading**, where performance and privacy align.
- **Server-side tagging** to reduce client scripts to one first-party beacon.
- **Tag budget and review cadence** as governance.
- **Worker offload (Partytown)** for simple, DOM-light analytics, after verifying data parity.

## Anti-Patterns
- **Synchronous `<script>` tags in `<head>` from vendors.** They block rendering. Fix: `next/script` strategy or `async`/`defer`.
- **Tag manager as a backdoor** for unreviewed heavy scripts. Fix: container governance, custom-HTML tag restrictions, CSP.
- **Anti-flicker snippets** that hide the page. Fix: server or edge experiments.
- **Loading chat SDKs on every page at load.** Fix: facade plus load on interaction.
- **Moving complex, DOM-heavy scripts to Partytown blindly.** Breakage, silent data loss. Fix: test thoroughly; keep them on the main thread with lazy loading if incompatible.
- **Using `beforeInteractive` for analytics.** Fix: `afterInteractive`/`lazyOnload`.
- **Social SDKs for simple share buttons.** Fix: plain intent links.

## Accessibility
- Third-party widgets (chat, consent banners, embeds) often fail WCAG. Audit them with automated and manual tests; the site owner remains responsible ([accessibility-legal-compliance](../accessibility-legal-compliance/Skill.md)).
- Facades must be real buttons with accessible names. Move focus into the loaded widget when opened.
- Consent banners must be keyboard-operable and must not obscure focused content (SC 2.4.11).
- Embedded iframes need `title` attributes.

## Responsive Design
- Chat launchers and sticky ad units can cover content on small screens. Test at 320–390 px.
- Ads: reserve slots per breakpoint. Don't load desktop-only units on mobile.

## Performance
- Third parties commonly account for a large share of main-thread time in field traces. Measure your own mix.
- Each new origin adds DNS, TCP and TLS setup. Consolidating through server-side tagging reduces connections and scripts.
- Partytown moves execution off the main thread, but synchronous DOM access through its proxy can be slow. It's still in beta.

## Security
- Third-party JavaScript runs with full page privileges and can read the DOM, cookies (non-HttpOnly) and form inputs. Treat vendors as supply-chain risk ([dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md)).
- Allowlist origins in the CSP `script-src`, ideally with nonces plus `strict-dynamic`; `next/script` supports a `nonce` ([content-security-policy](../content-security-policy/Skill.md)).
- Use SRI (`integrity`) for versioned static vendor files. It doesn't work for auto-updating loaders.
- Keep tags off sensitive pages (checkout, account, payment forms) unless required. PCI DSS v4 requires a script inventory and integrity monitoring on payment pages.
- Sandbox embeds (`<iframe sandbox allow-scripts allow-same-origin>` only as needed). Set `referrerpolicy`.

## Testing
- Playwright: assert no third-party requests before consent. Assert chat loads only after clicking the facade.
- Blocked-domain performance comparison in CI (WebPageTest or LHCI with `blockedUrlPatterns`).
- CSP report-only monitoring in staging to catch unexpected origins.
- Manual accessibility check of each widget.

## Tooling
- `next/script` (strategies: `beforeInteractive`, `afterInteractive` default, `lazyOnload`, `worker` experimental and Pages Router only): Active.
- `@next/third-parties` (Google Tag Manager/Analytics, YouTube, Maps embeds): Experimental.
- Partytown (QwikDev): Beta, maintained.
- Chrome DevTools "3rd parties" insight, request blocking: Active.
- Server-side tagging: GTM server containers, Cloudflare Zaraz: Active (vendor products).
- `lite-youtube-embed` / `react-lite-youtube-embed`: Active (community).

## Framework Notes
- **Next.js**:
  - `next/script` is the default mechanism in the App Router. `strategy="worker"` does not work in the App Router (Pages Router only, experimental `nextScriptWorkers` flag). Use Partytown manually if needed.
  - `onLoad`, `onReady` and `onError` only work in Client Components.
  - `beforeInteractive` scripts must be in the root layout. They run once per document, not on client navigations.
  - Put route-specific tags in that route's layout or page, so they load only there.
  - For nonce-based CSP, see [content-security-policy](../content-security-policy/Skill.md). Rendering-level performance is covered in [nextjs-performance](../nextjs-performance/Skill.md).
- **React (Vite SPA)**:
  - Add scripts dynamically (a helper like the one above) from an effect or idle callback. Keep global tags out of `index.html`, or mark them `async`/`defer`.
  - SPA page views need manual tracking on route change. Don't reload tag managers per route.

## AI Agent Guidance
- Do: ask for or produce a tag inventory. Pick the latest acceptable loading trigger. Use facades for embeds and chat.
- Do: use `next/script` with explicit strategies in Next.js, and gate non-essential tags on consent.
- Don't: add third-party `<script>` tags to `<head>` synchronously, use `beforeInteractive` for analytics, or use `strategy="worker"` in App Router code.
- Don't: widen the CSP to `*` to make a tag work.
- Before declaring done: a load trace shows no third-party long tasks before LCP, no requests before consent (if required), facade interactions work with keyboard, the CSP allows only intended origins, and the tag's measured cost is recorded.

## Examples
```ts
// lighthouserc.cjs — measure marginal cost of a vendor by blocking it in one collection run
module.exports = { ci: { collect: { settings: { blockedUrlPatterns: ['*widget.example-chat.com*'] } } } };
```

## Related Skills
- [inp-optimization](../inp-optimization/Skill.md): input delay from third parties
- [cls-prevention](../cls-prevention/Skill.md): ads and embeds shifting layout
- [content-security-policy](../content-security-policy/Skill.md): allowlisting and nonces
- [web-workers-offloading](../web-workers-offloading/Skill.md): worker offload concepts
- [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md): server-side experiments
- [performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md): third-party budgets and monitoring
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md): vendor risk

## Sources
- [Next.js Script Component API](https://nextjs.org/docs/app/api-reference/components/script) (Official): strategies, App Router restrictions, onLoad/onReady/onError (docs v16.3.5)
- [Next.js: Third Party Libraries (@next/third-parties)](https://nextjs.org/docs/app/guides/third-party-libraries) (Official): GTM/GA/YouTube/Maps components
- [web.dev: Efficiently load third-party JavaScript](https://web.dev/articles/efficiently-load-third-party-javascript) (Official): loading strategies, facades
- [Partytown](https://partytown.qwik.dev/) (Open Source): worker offload, beta status, limitations
- [Chrome DevTools Performance reference](https://developer.chrome.com/docs/devtools/performance/reference) (Official): 3rd-party dimming and insights
- [DebugBear: Partytown web workers](https://www.debugbear.com/blog/partytown-web-workers) (Community): practical trade-offs
- [Harry Roberts: third-party performance talks](https://csswizardry.com/) (Community): governance and measurement

## License / Usage Notes
Summarized. Partytown MIT. Examples original. Vendor names are illustrative.

## Quality Tier
A: Official Next.js script behavior verified. `@next/third-parties` experimental status should be rechecked per release.

## Status
Active

## Last Verified
2026-09-15
