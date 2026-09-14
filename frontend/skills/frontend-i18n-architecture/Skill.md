# Frontend i18n Architecture

## Summary
Architecture for internationalizing React and Next.js apps: locale detection and routing, message catalogs and ICU MessageFormat, formatting with `Intl`, type-safe keys, loading strategies (server-only messages, per-route splitting), RTL, translation workflow, and testing. Uses next-intl (Next.js App Router) and react-i18next or Paraglide JS (Vite SPA) as reference implementations. Status notes: Unicode MessageFormat 2 is stable at CLDR but `Intl.MessageFormat` is stuck at TC39 Stage 1; Temporal is ES2026 but not yet in Safari.

## Category
Architecture

## Subcategories
Locale routing, ICU messages, pluralization, Intl formatting, RTL, type-safe translations, message loading, translation management, pseudo-localization

## Problem It Solves
String concatenation, hard-coded formats, and locale logic scattered through components make localization expensive and buggy: broken plurals, wrong dates/currency, untranslatable sentence fragments, layout breaks in German or Arabic, SEO-invisible locales, and huge message bundles shipped to every page.

## When To Use
- Any product that will ship in more than one language or region (plan early; retrofitting is costly).
- Single-language apps that still need correct number/date/currency formatting for multiple regions.

## When Not To Use
- Content-heavy sites where a CMS handles localized content — still use this for UI chrome, but don't put article bodies in message catalogs.

## Core Principles
1. **Locale is explicit state** — in the URL (preferred for public pages) or user profile; never inferred on every render from headers alone.
2. **Full sentences with placeholders, never concatenation.** Translators need context and word order freedom.
3. **ICU MessageFormat for plurals, select, and gender** — never `count === 1 ? ... : ...` in code.
4. **Format with `Intl`**, not manual strings: numbers, currency, dates, relative time, lists, units.
5. **Keys are typed and stable;** missing keys fail CI.
6. **Ship only needed messages** — server-render translations where possible; split client messages.
7. **Design for expansion and bidirectionality** — logical CSS properties, `dir` attribute, flexible layouts.

## Best Practices
- Locale identifiers: BCP 47 (`en-US`, `pt-BR`, `ar`); normalize with `Intl.Locale`; keep a supported-locales list and a fallback chain (`pt-BR` -> `pt` -> `en`).
- Routing for public/SEO pages: path prefix (`/de/pricing`) with `hreflang` alternates and localized metadata; app-only (logged-in) routes can use a cookie/profile locale without prefix.
- Detection order: explicit URL -> user setting/cookie -> `Accept-Language` negotiation (only on first visit, then redirect/persist) -> default.
- Set `<html lang={locale} dir={dir}>` on the server.
- Messages: namespaced JSON per locale (`messages/en.json`), with ICU syntax: `"cart": "{count, plural, =0 {Your cart is empty} one {# item} other {# items}}"`.
- Provide translator context via descriptions (message metadata in TMS) and screenshots.
- Rich text via tag functions (`t.rich('terms', { link: (chunks) => <Link href="/terms">{chunks}</Link> })`), never `dangerouslySetInnerHTML`.
- Time zones: store UTC; format in user time zone with `Intl.DateTimeFormat(locale, { timeZone })`; pass the time zone from server to client to avoid hydration mismatches.
- Currency: format with ISO code from data, not from locale (`€` price for a `en-US` user stays EUR).
- Pseudo-localization locale (`en-XA` style with accents/expansion) in dev/staging to catch hard-coded strings and truncation.
- Use a TMS (Crowdin, Lokalise, Phrase, Tolgee, inlang/Fink) with CI sync; source locale lives in repo.
- Lint for hard-coded JSX strings (`eslint-plugin-i18next` `no-literal-string` or equivalent) in UI folders.

## Implementation Guidance

### Library decision table
| Stack | Choice | Why |
|---|---|---|
| Next.js App Router | next-intl (v4) | RSC support (`getTranslations`), routing + proxy integration, ICU, typed messages |
| Next.js, bundle-size critical, typed functions | Paraglide JS 2 | Compiles messages to tree-shakable functions |
| Vite React SPA, large existing ecosystem | react-i18next (i18next) | Plugins, lazy namespaces, mature |
| Vite React SPA, type-safety + small bundles | Paraglide JS 2 | Compile-time, per-message tree-shaking |
| Heavy ICU/format.js investment | react-intl (FormatJS) | Standards-aligned ICU tooling |

### next-intl on Next.js 16 (locale-prefixed routing)
```ts
// src/i18n/routing.ts
import { defineRouting } from 'next-intl/routing';
export const routing = defineRouting({ locales: ['en', 'de', 'ar'], defaultLocale: 'en' });
```
```ts
// src/proxy.ts  (named middleware.ts before Next.js 16)
import createMiddleware from 'next-intl/middleware';
import { routing } from './i18n/routing';
export default createMiddleware(routing);
export const config = { matcher: '/((?!api|trpc|_next|_vercel|.*\\..*).*)' };
```
```ts
// src/i18n/navigation.ts
import { createNavigation } from 'next-intl/navigation';
import { routing } from './routing';
export const { Link, redirect, usePathname, useRouter, getPathname } = createNavigation(routing);
```
```ts
// src/i18n/request.ts
import { getRequestConfig } from 'next-intl/server';
import { hasLocale } from 'next-intl';
import { routing } from './routing';
export default getRequestConfig(async ({ requestLocale }) => {
  const requested = await requestLocale;
  const locale = hasLocale(routing.locales, requested) ? requested : routing.defaultLocale;
  return { locale, messages: (await import(`../../messages/${locale}.json`)).default };
});
```
(next-intl docs for Next.js 16.3+ also show resolving the locale via `next/root-params`; follow the docs for your exact version.)
```tsx
// src/app/[locale]/layout.tsx
import { NextIntlClientProvider, hasLocale } from 'next-intl';
import { setRequestLocale } from 'next-intl/server';
import { notFound } from 'next/navigation';
import { routing } from '@/i18n/routing';
export function generateStaticParams() { return routing.locales.map((locale) => ({ locale })); }
export default async function LocaleLayout({ children, params }: { children: React.ReactNode; params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();
  setRequestLocale(locale); // enables static rendering
  const dir = new Intl.Locale(locale).getTextInfo?.().direction ?? (locale === 'ar' ? 'rtl' : 'ltr');
  return (
    <html lang={locale} dir={dir}>
      <body><NextIntlClientProvider>{children}</NextIntlClientProvider></body>
    </html>
  );
}
```
```tsx
// Server Component usage
import { getTranslations } from 'next-intl/server';
export default async function Cart({ count }: { count: number }) {
  const t = await getTranslations('Cart');
  return <h1>{t('title', { count })}</h1>;
}
```
`Intl.Locale.prototype.getTextInfo` support varies (Firefox shipped late); keep a fallback RTL list.

### Type-safe messages (next-intl)
```ts
// src/global.d.ts
import type messages from '../messages/en.json';
import type { routing } from '@/i18n/routing';
declare module 'next-intl' {
  interface AppConfig { Locale: (typeof routing.locales)[number]; Messages: typeof messages; }
}
```

### Intl formatting cheatsheet
```ts
new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(1234.5); // 1.234,50 €
new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium', timeZone: 'Europe/London' }).format(date);
new Intl.RelativeTimeFormat('es', { numeric: 'auto' }).format(-1, 'day');               // ayer
new Intl.ListFormat('en', { type: 'conjunction' }).format(['A', 'B', 'C']);              // A, B, and C
new Intl.PluralRules('ar').select(3);                                                     // few
new Intl.DurationFormat('fr', { style: 'short' }).format({ hours: 1, minutes: 5 });      // Baseline 2025
```

### Standards status (Sept 2026)
| Feature | Status | Guidance |
|---|---|---|
| ICU MessageFormat 1 | Ubiquitous | Default message syntax |
| Unicode MessageFormat 2 | Stable at CLDR (LDML 47/48) | Libraries experimenting (messageformat v4, i18next migration in progress); don't migrate catalogs yet unless your TMS supports it |
| `Intl.MessageFormat` (TC39) | Stage 1, stalled | Do not expect native support |
| Temporal | ES2026 (Stage 4 Mar 2026); Chrome 144+, Firefox 139+; Safari not shipped | Polyfill (`temporal-polyfill`) or keep `Date` + `Intl` |
| `Intl.DurationFormat` | Baseline 2025 | Safe to use |

## Recommended Workflow
1. Decide routing strategy (prefix vs cookie) and supported locales with fallback chains.
2. Set up library, `lang`/`dir`, and locale negotiation in `proxy.ts` (Next) or at app bootstrap (SPA).
3. Extract strings to namespaced catalogs; add no-literal-string lint.
4. Replace manual formatting with `Intl` helpers; pass time zone explicitly.
5. Add typed keys and a CI check for missing/unused keys across locales.
6. Convert CSS to logical properties; test RTL and pseudo-locale.
7. Connect TMS sync; add `hreflang` and localized metadata for public pages.

## Patterns
- **Server-side translation** in RSC; only pass needed namespaces to `NextIntlClientProvider` for client components (`messages={pick(messages, ['Cart'])}`) when bundle matters.
- **Locale-aware Link/redirect** generated from routing config.
- **Formatter helpers** (`useFormatter`/`getFormatter`) with app defaults (currency display, time zone).
- **Pseudo-locale** for QA.
- **Message ownership per feature** (`features/checkout/messages/en.json`) merged at build time.

## Anti-Patterns
- **Concatenation** (`t('you_have') + count + t('items')`) — Fix: ICU placeholders/plurals.
- **Reusing one key in different contexts** ("Open" verb vs adjective) — Fix: separate keys with descriptions.
- **Formatting dates with `toLocaleString()` without explicit locale/timeZone during SSR** — hydration mismatch. Fix: explicit locale and time zone from server.
- **Flags for languages** — languages aren't countries. Fix: language names in their own script (`Deutsch`, `العربية`).
- **Locale by IP geolocation only** — Fix: Accept-Language + explicit user choice persisted.
- **Physical CSS (`margin-left`)** — breaks RTL. Fix: logical properties (`margin-inline-start`).
- **Shipping all locales' messages to the client** — Fix: load per locale on server; split client namespaces.
- **HTML in translations rendered via innerHTML** — XSS risk. Fix: rich-text tag functions.

## Accessibility
- `lang` on `<html>` (WCAG 3.1.1 Language of Page) and `lang` on inline foreign-language fragments (3.1.2 Language of Parts).
- `dir="rtl"` for RTL locales; mirror directional icons; keep focus order logical.
- Translate accessible names too: `aria-label`, `alt`, live region announcements, and `<title>`.
- Language switcher: accessible name ("Language"), each option labeled in its own language with `lang` attribute.

## Responsive Design
- Allow 30–40% text expansion (German, Finnish); avoid fixed-width buttons; test truncation with pseudo-locale.
- Use logical properties and `text-align: start`; check container queries under longer strings.
- CJK line-breaking: consider `word-break: auto-phrase` (Chromium) / `line-break` settings.

## Performance
- RSC translation keeps message catalogs off the client for server-rendered text.
- Static rendering per locale with `generateStaticParams` + `setRequestLocale` (next-intl).
- Avoid loading all `Intl` polyfills; modern browsers cover most APIs.
- Paraglide's compiled messages tree-shake unused strings (benchmarks show substantially smaller bundles than runtime dictionaries — verify for your app).

## Security
- Treat translations as untrusted input from vendors/TMS: no raw HTML rendering; review placeholder integrity in CI.
- Validate locale param against the supported list before using it in dynamic imports (prevents path traversal via `import(\`../messages/${locale}.json\`)`).

## Testing
- CI: missing keys, unused keys, ICU syntax validation, placeholder parity across locales.
- Unit: formatter helpers with fixed time zone (`TZ=UTC` in test env).
- E2E (Playwright): each locale route renders `lang`/`dir`; locale switch preserves path; RTL visual snapshots.
- Pseudo-locale screenshot pass for hard-coded strings.

## Tooling
- next-intl v4 — Active (Next.js App Router; proxy.ts naming for Next 16).
- Paraglide JS 2 (inlang) — Active.
- i18next / react-i18next — Active.
- react-intl (FormatJS) — Active.
- messageformat v4 (MF2 reference) — Active, experimental adoption.
- `temporal-polyfill` / `@js-temporal/polyfill` — Active.
- eslint-plugin-i18next — Active (literal string detection).
- TMS: Crowdin, Lokalise, Phrase, Tolgee — Commercial/Open core.

## Framework Notes
- **React (Vite SPA):** react-i18next with `i18next-http-backend` lazy namespaces or Paraglide's Vite plugin; set `document.documentElement.lang/dir` on locale change; locale in URL via router (`/:locale/*`) for shareability; no SEO benefit without SSR/prerendering.
- **Next.js App Router:** next-intl with `[locale]` segment and `proxy.ts`; `getTranslations` in Server Components, `useTranslations` in Client Components; localized `generateMetadata` and `alternates.languages` for hreflang; `setRequestLocale` to keep pages static. For logged-in apps without prefixes, next-intl supports locale from cookie/user settings without routing.

## AI Agent Guidance
- Never add user-visible literal strings in JSX; add keys to the source catalog (and placeholders in other locales per team policy).
- Do: use ICU plurals/select, `Intl`/library formatters with explicit time zone, logical CSS properties, locale-aware `Link`.
- Don't: concatenate translated fragments, use `toLocaleString()` without arguments in SSR, render translations with innerHTML, or hard-code `/en/` paths.
- Verify: missing-key check passes, typecheck passes with typed messages, page renders in an RTL locale and pseudo-locale without layout breaks.

## Examples
```json
// messages/en.json
{
  "Cart": {
    "title": "{count, plural, =0 {Your cart is empty} one {# item in your cart} other {# items in your cart}}",
    "updated": "Updated {when, time, short}",
    "terms": "By continuing you accept our <link>terms</link>."
  }
}
```
```tsx
'use client';
import { useTranslations, useFormatter } from 'next-intl';
export function CartSummary({ count, total, currency }: { count: number; total: number; currency: string }) {
  const t = useTranslations('Cart');
  const format = useFormatter();
  return (
    <section aria-live="polite">
      <h2>{t('title', { count })}</h2>
      <p>{format.number(total, { style: 'currency', currency })}</p>
    </section>
  );
}
```

## Related Skills
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — Next.js routing depth
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md) — RTL layout
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — hreflang/metadata
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — locale negotiation in proxy
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — writing translatable copy
- [seo-for-frontend](../seo-for-frontend/Skill.md) — international SEO

## Sources
- [next-intl: App Router getting started](https://next-intl.dev/docs/getting-started/app-router) — Open Source (official lib docs) — setup
- [next-intl: Routing setup](https://next-intl.dev/docs/routing/setup) — Open Source — proxy.ts, defineRouting, createNavigation
- [MDN: Intl](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl) — Official — formatting APIs
- [TC39 proposal-intl-messageformat](https://github.com/tc39/proposal-intl-messageformat) — Official — Stage 1 status
- [Locize: MessageFormat 2 in i18next (May 2026)](https://www.locize.com/blog/messageformat-2-i18next/) — Community — MF2 adoption status
- [Temporal — web-features explorer](https://web-platform-dx.github.io/web-features-explorer/features/temporal/) — Official — Baseline status
- [Paraglide JS vs react-i18next](https://paraglidejs.com/paraglide-vs-react-i18next) — Community (vendor) — compile-time tradeoffs
- [W3C: Language tags / i18n best practices](https://www.w3.org/International/techniques/authoring-html) — Official

## License / Usage Notes
Summarized; code adapted from documented APIs, not copied verbatim beyond minimal config shapes. next-intl MIT, i18next MIT, Paraglide MIT.

## Quality Tier
A — official library docs verified Sept 2026; next-intl request-config details differ between 16.x minors (root-params), flagged.

## Status
Active

## Last Verified
2026-09-15
