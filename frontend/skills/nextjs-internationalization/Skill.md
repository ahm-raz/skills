# Next.js Internationalization (i18n)

## Summary
The App Router has no built-in `i18n` config (that was Pages Router only). Localization is built from a root dynamic segment (`app/[lang]` or `app/[locale]`), locale negotiation and redirects in `proxy.ts`, server-side dictionaries loaded in Server Components, `generateStaticParams` for locale prerendering, and — new in Next.js 16.3 — `next/root-params` getters (`import { lang } from 'next/root-params'`) that read the locale anywhere on the server and participate correctly in `'use cache'` keys. next-intl (v4, `proxy.ts`-aware, uses root params on 16.3+) is the most common library.

## Category
Next.js

## Subcategories
Locale routing, proxy locale detection, [lang] segment, dictionaries, root params, next-intl, hreflang, generateStaticParams, formatting, RTL, localized metadata

## Problem It Solves
Prop-drilling locale through every component, shipping all translations to the client, duplicate content without hreflang, locale detection that ignores explicit user choice, invalid locales causing runtime errors, and i18n setups that force every route into request-time rendering.

## When To Use
- Multi-language sites/apps using sub-path (`/de/products`) or domain (`acme.de`) routing.
- Adopting next-intl or a custom dictionary approach on Next.js 16.
- Making localized routes static/cached under Cache Components.

## When Not To Use
- Organization-wide i18n architecture, translation workflow, ICU message governance (see [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md)).
- RTL styling details (see [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md)).
- Single-language apps needing only number/date formatting (use `Intl` directly).

## Core Principles
1. **Locale lives in the URL** (sub-path or domain) for shareability, caching, and SEO.
2. **Negotiate once, respect explicit choice.** `Accept-Language` for first visit; cookie/URL choice wins afterwards.
3. **Translations load on the server;** send only needed messages to Client Components.
4. **Validate the locale** (`hasLocale`) and `notFound()` for unsupported values.
5. **Locale is a root param.** Read with `next/root-params` in Server Components (16.3+) instead of prop drilling; it keys caches only when read.
6. **Every localized page declares alternates** (`hreflang`) and sets `<html lang dir>`.

## Best Practices
- Put the root layout inside `app/[lang]/layout.tsx` so `<html lang>` is per-locale (use multiple root layouts if a non-localized section exists).
- `generateStaticParams` in the `[lang]` layout returns all locales (required ≥1 under Cache Components).
- Dictionaries: `import 'server-only'` (unless using `next/root-params`, which already fails in client code), lazy `import()` per locale.
- For client components, pass a narrowed message subset (next-intl `NextIntlClientProvider` with `pick`) instead of the whole catalog.
- Use `Intl.DateTimeFormat`/`NumberFormat` (or next-intl `useFormatter`) with explicit timezone to avoid hydration mismatches.
- Exclude `api`, `_next`, static files from the locale proxy matcher.
- Store explicit locale choice in a cookie (`NEXT_LOCALE`) and honor it in proxy.
- Localize `metadata` (titles/descriptions) and `alternates.languages`; include `alternates.languages` in `sitemap.ts`.
- Set `dir="rtl"` for RTL locales and use CSS logical properties.

## Implementation Guidance

### Root params limits (16.3)
| Context | `next/root-params` |
|---|---|
| Server Components, server utilities, `generateStaticParams` | Yes |
| Inside `'use cache'` | Yes (only read params join the key) |
| Client Components | No (build error) |
| Server Actions | No |
| Route Handlers | Not yet (planned) |
| `unstable_cache` | No (runtime error) |

### Custom setup file tree
```txt
proxy.ts
app/
└── [lang]/
    ├── layout.tsx
    ├── page.tsx
    ├── dictionaries.ts
    └── dictionaries/{en,de,ar}.json
```

### Proxy locale negotiation
```ts
// proxy.ts
import { NextResponse, type NextRequest } from 'next/server'
import { match } from '@formatjs/intl-localematcher'
import Negotiator from 'negotiator'

const locales = ['en', 'de', 'ar'] as const
const defaultLocale = 'en'

function getLocale(req: NextRequest) {
  const cookie = req.cookies.get('NEXT_LOCALE')?.value
  if (cookie && (locales as readonly string[]).includes(cookie)) return cookie
  const languages = new Negotiator({ headers: { 'accept-language': req.headers.get('accept-language') ?? '' } }).languages()
  return match(languages, locales as unknown as string[], defaultLocale)
}

export function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl
  const hasLocale = locales.some((l) => pathname === `/${l}` || pathname.startsWith(`/${l}/`))
  if (hasLocale) return
  req.nextUrl.pathname = `/${getLocale(req)}${pathname}`
  return NextResponse.redirect(req.nextUrl)
}

export const config = { matcher: ['/((?!api|_next|.*\\..*).*)'] }
```

### Dictionaries with root params
```ts
// app/[lang]/dictionaries.ts
import { lang } from 'next/root-params'
import { notFound } from 'next/navigation'

const dictionaries = {
  en: () => import('./dictionaries/en.json').then((m) => m.default),
  de: () => import('./dictionaries/de.json').then((m) => m.default),
  ar: () => import('./dictionaries/ar.json').then((m) => m.default),
}
export type Locale = keyof typeof dictionaries
export const hasLocale = (l: string): l is Locale => l in dictionaries

export async function getDictionary() {
  const l = await lang()
  if (!hasLocale(l)) notFound()
  return dictionaries[l]()
}
```

```tsx
// app/[lang]/layout.tsx
import { lang } from 'next/root-params'
import { notFound } from 'next/navigation'
import { hasLocale } from './dictionaries'

export async function generateStaticParams() {
  return [{ lang: 'en' }, { lang: 'de' }, { lang: 'ar' }]
}

export default async function RootLayout({ children }: LayoutProps<'/[lang]'>) {
  const l = await lang()
  if (!hasLocale(l)) notFound()
  return (
    <html lang={l} dir={l === 'ar' ? 'rtl' : 'ltr'}>
      <body>{children}</body>
    </html>
  )
}
```

```tsx
// app/[lang]/page.tsx
import { getDictionary } from './dictionaries'
export default async function Page() {
  const t = await getDictionary()
  return <button>{t.products.cart}</button>
}
```

### next-intl (Next.js 16.3+) essentials
```ts
// src/i18n/routing.ts
import { defineRouting } from 'next-intl/routing'
export const routing = defineRouting({ locales: ['en', 'de'], defaultLocale: 'en' })

// src/i18n/navigation.ts
import { createNavigation } from 'next-intl/navigation'
import { routing } from './routing'
export const { Link, redirect, usePathname, useRouter, getPathname } = createNavigation(routing)

// src/proxy.ts
import createMiddleware from 'next-intl/middleware'
import { routing } from './i18n/routing'
export default createMiddleware(routing)
export const config = { matcher: '/((?!api|trpc|_next|_vercel|.*\\..*).*)' }

// src/i18n/request.ts
import * as rootParams from 'next/root-params'
import { notFound } from 'next/navigation'
import { getRequestConfig } from 'next-intl/server'
import { hasLocale } from 'next-intl'
import { routing } from './routing'
export default getRequestConfig(async ({ locale }) => {
  if (!locale) {
    const p = await rootParams.locale()
    if (hasLocale(routing.locales, p)) locale = p
    else notFound()
  }
  return { locale, messages: (await import(`../../messages/${locale}.json`)).default }
})

// next.config.ts
import createNextIntlPlugin from 'next-intl/plugin'
export default createNextIntlPlugin()({ /* nextConfig */ })
```
Use `getTranslations` in async Server Components, `useTranslations` in client/sync components, and the generated `Link`/`useRouter` for locale-aware navigation. On versions before 16.3, next-intl requires `setRequestLocale(locale)` in layouts/pages for static rendering (or `experimental.rootParams`).

### Localized metadata and alternates
```tsx
export async function generateMetadata(): Promise<Metadata> {
  const t = await getDictionary()
  return {
    title: t.meta.homeTitle,
    alternates: { canonical: '/', languages: { en: '/en', de: '/de', ar: '/ar', 'x-default': '/en' } },
  }
}
```

## Recommended Workflow
1. Decide routing strategy (sub-path vs domain) and locale list.
2. Choose library (next-intl) or custom dictionaries.
3. Move routes under `app/[lang]`; create per-locale root layout with `generateStaticParams`.
4. Add proxy negotiation with cookie override and strict matcher.
5. Load messages server-side; pass subsets to client components.
6. Localize metadata, sitemap alternates, and `<html lang dir>`.
7. Test invalid locale 404, redirects, static generation, RTL.

## Patterns
- **Locale switcher** that sets `NEXT_LOCALE` cookie via Server Action then navigates to the same path in the new locale.
- **Cached localized CMS content:** `'use cache'` function reading `lang()` inside (key includes only lang).
- **Domain routing:** proxy maps `host` to locale and rewrites to `/[lang]`.
- **Message splitting by namespace** to keep client payloads small.

## Anti-Patterns
- **Using `next.config` `i18n` in App Router** — no effect. Fix: `[lang]` segment.
- **Prop-drilling `lang`** through deep trees on 16.3+ — noise and bugs. Fix: `next/root-params`.
- **Reading `headers()` for Accept-Language in pages** — forces request-time rendering for every page. Fix: negotiate in proxy, locale in URL.
- **Shipping full translation JSON to the client** — bundle bloat. Fix: server rendering + message subsets.
- **Locale redirect without cookie override** — users can't choose another language. Fix: honor cookie.
- **No `hasLocale` validation** — `/xx/` crashes dynamic imports. Fix: validate + `notFound()`.
- **Calling `lang()` in Server Actions/Route Handlers** — unsupported. Fix: pass locale explicitly or read from URL/cookie.
- **Formatting dates without timezone** — hydration mismatch. Fix: explicit `timeZone`.

## Accessibility
- `<html lang>` per locale (WCAG 3.1.1); `lang` on inline foreign-language phrases (WCAG 3.1.2).
- `dir="rtl"` for RTL languages and mirrored layouts via logical properties.
- Language switcher: list languages in their own names (`Deutsch`, `العربية`) with `lang` attributes, keyboard accessible, not flag-only.
- Localize accessible names, `alt` text, `aria-label`s, and live-region messages.

## Responsive Design
- Text expansion (German ~30% longer) — design flexible containers; avoid fixed-width buttons.
- RTL: use `ms-*`/`me-*`/`start`/`end` utilities (Tailwind logical classes) and test mirrored layouts at all breakpoints.

## Performance
- Locale segments with `generateStaticParams` + cached content keep pages in the static shell.
- Root-params-based caches key only on `lang` when read → high hit rates.
- Avoid proxy work on assets via matcher.

## Security
- Treat locale param as untrusted: validate against an allowlist before dynamic imports or file paths (prevents path traversal via `import(\`./${locale}.json\`)`).
- Sanitize translator-provided HTML; prefer rich-text APIs over `dangerouslySetInnerHTML`.

## Testing
- Unit: dictionary loaders, `hasLocale`, message key completeness across locales (CI script).
- E2E: `/` redirects based on `Accept-Language`; cookie override; `/xx` returns 404; `<html lang dir>` correct; switcher preserves path.
- Visual regression for RTL and long-text locales.

## Tooling
- next-intl (v4), `@formatjs/intl-localematcher`, `negotiator`.
- Alternatives listed by Next.js docs: next-international, next-i18n-router, paraglide-next, lingui, tolgee, next-intlayer, gt-next.
- i18n Ally / translation management platforms for key coverage.

## Framework Notes
- 16.3: `next/root-params` stable feature; next-intl uses it by default (earlier needs `experimental.rootParams` or `setRequestLocale`).
- v16: `proxy.ts` naming — libraries export `createMiddleware` but file is `proxy.ts`.
- React (Vite SPA): use react-intl/i18next/Lingui on the client with lazy-loaded catalogs; locale in URL via the client router; no server negotiation (do it at CDN edge or in the app shell).

## AI Agent Guidance
- Check Next.js version: ≥16.3 → use `next/root-params`; otherwise pass `lang` from params.
- Always add `hasLocale` validation, `<html lang dir>`, `generateStaticParams`, alternates.
- Don't read `Accept-Language` in pages; don't use Pages Router `i18n` config.
- Before done: build succeeds with all locales prerendered, invalid locale → 404, switcher works, no full-catalog client bundles.

## Examples
```tsx
// Language switcher (client) using next-intl navigation
'use client'
import { useLocale } from 'next-intl'
import { usePathname, useRouter } from '@/i18n/navigation'

const LOCALES = [{ code: 'en', label: 'English' }, { code: 'de', label: 'Deutsch' }]

export function LocaleSwitcher() {
  const locale = useLocale()
  const pathname = usePathname()
  const router = useRouter()
  return (
    <label>
      <span className="sr-only">Language</span>
      <select value={locale} onChange={(e) => router.replace(pathname, { locale: e.target.value })}>
        {LOCALES.map((l) => <option key={l.code} value={l.code} lang={l.code}>{l.label}</option>)}
      </select>
    </label>
  )
}
```

## Related Skills
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — i18n architecture
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md) — RTL styling
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — locale negotiation
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — hreflang/localized metadata
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — root params in cache keys
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — multiple root layouts

## Sources
- [Internationalization guide](https://nextjs.org/docs/app/guides/internationalization) — Official — proxy negotiation, [lang], dictionaries, root params, static rendering, library list
- [next/root-params reference](https://nextjs.org/docs/app/api-reference/functions/next-root-params) — Official — getters, restrictions, caching behavior, v16.3
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) — Official — root params announcement
- [next-intl routing setup](https://next-intl.dev/docs/routing/setup) — Open Source — defineRouting, proxy.ts, request.ts with rootParams
- [next-intl App Router getting started](https://next-intl.dev/docs/getting-started/app-router) — Open Source — plugin, provider, translations API

## License / Usage Notes
Next.js MIT; next-intl MIT; negotiator MIT; @formatjs MIT. Summarized; code adapted and original.

## Quality Tier
A — Version-precise with the new root params API and verified next-intl setup; next-intl version specifics beyond routing were not exhaustively fetched.

## Status
Active

## Last Verified
2026-09-15
