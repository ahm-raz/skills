# Manifest — W01 (Architecture, Design Systems, Security, Tooling)

Scope: React + Next.js (TypeScript) per TAXONOMY scope note (2026-09-15). All 21 assigned slugs written; 0 added; 0 skipped. Last Verified for all: 2026-09-15.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| frontend-architecture-principles | Frontend Architecture Principles | Architecture | React, Next.js | A | Active | https://feature-sliced.design/docs/get-started/overview |
| feature-based-architecture | Feature-Based Architecture | Architecture | React, Next.js | A | Active | https://feature-sliced.design/docs/get-started/overview |
| component-api-design | Component API Design | Architecture | React, Next.js | A | Active | https://www.radix-ui.com/primitives/docs/guides/composition |
| design-system-architecture | Design System Architecture | Architecture | React, Next.js | A | Active | https://www.designtokens.org/tr/drafts/format/ |
| design-token-architecture | Design Token Architecture | Architecture | React, Next.js (platform-agnostic tokens) | S | Active | https://www.designtokens.org/tr/drafts/format/ |
| design-system-governance | Design System Governance | Architecture | React, Next.js | A | Active | https://medium.com/eightshapes-llc/team-models-for-scaling-a-design-system-2cf9d03be6a0 |
| monorepo-frontend-architecture | Monorepo Frontend Architecture | Tooling | React, Next.js | A | Active | https://turborepo.dev/docs/reference/configuration |
| micro-frontends | Micro-Frontends | Architecture | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/multi-zones |
| frontend-state-architecture | Frontend State Architecture | Architecture | React, Next.js | A | Active | https://tanstack.com/query/latest |
| frontend-api-layer-design | Frontend API Layer Design | Architecture | React, Next.js | A | Active | https://openapi-ts.dev/openapi-fetch/ |
| frontend-error-handling-architecture | Frontend Error Handling Architecture | Architecture | React, Next.js | A | Active | https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation |
| frontend-i18n-architecture | Frontend i18n Architecture | Architecture | React, Next.js | A | Active | https://next-intl.dev/docs/routing/setup |
| feature-flags-and-experimentation | Feature Flags and Experimentation | Architecture | React, Next.js | A | Active | https://openfeature.dev/docs/reference/sdks/client/web/react/ |
| frontend-observability | Frontend Observability | Tooling | React, Next.js | A | Active | https://nextjs.org/docs/app/guides/open-telemetry |
| typescript-for-frontend | TypeScript for Frontend | Tooling | React, Next.js | S | Active | https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/ |
| frontend-build-tooling | Frontend Build Tooling | Tooling | React (Vite), Next.js | A | Active | https://vite.dev/blog/announcing-vite8 |
| frontend-security-fundamentals | Frontend Security Fundamentals | Security | React, Next.js | S | Active | https://top10.owasp.org/2025 |
| content-security-policy | Content Security Policy | Security | React, Next.js | S | Active | https://nextjs.org/docs/app/guides/content-security-policy |
| frontend-auth-token-handling | Frontend Auth Token Handling | Security | React, Next.js | S | Active | https://www.rfc-editor.org/info/rfc10017/ |
| dependency-supply-chain-security | Dependency and Supply Chain Security | Security | React, Next.js | S | Active | https://pnpm.io/supply-chain-security |
| linting-and-formatting | Linting and Formatting | Tooling | React, Next.js | A | Active | https://eslint.org/blog/2026/02/eslint-v10.0.0-released/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Design Tokens Format Module 2025.10 | https://www.designtokens.org/tr/drafts/format/ | Official | $value/$type/$extends/$root, types, alias syntax, color/dimension objects, file extension | First stable token spec | S | 2026-09-15 |
| Design Tokens Resolver Module 2025.10 | https://www.designtokens.org/tr/drafts/resolver/ | Official | sets, modifiers/contexts, resolutionOrder, version field | Standard theming/multi-brand | S | 2026-09-15 |
| DTCG stable announcement | https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/ | Official | Stability date, adopters | Confirms spec status | A | 2026-09-15 |
| Feature-Sliced Design docs | https://feature-sliced.design/docs/get-started/overview | Community | Layers, import rule, processes deprecated, v2.1, Steiger | Most complete feature architecture methodology | A | 2026-09-15 |
| Nx: Enforce module boundaries | https://nx.dev/docs/features/enforce-module-boundaries | Official | depConstraints flat config, tags, Conformance/Oxlint alternatives | Boundary enforcement | A | 2026-09-15 |
| Nx 23 release blog | https://nx.dev/blog/nx-23-release | Official | Nx 23.x current (23.2 Sept 2026) | Version currency | A | 2026-09-15 |
| Turborepo Boundaries | https://turborepo.dev/docs/reference/boundaries | Experimental | Tags/rules syntax; experimental status | Monorepo boundaries | A | 2026-09-15 |
| Turborepo configuration | https://turborepo.dev/docs/reference/configuration | Official | turbo.json tasks/env/outputs | Monorepo caching | A | 2026-09-15 |
| pnpm supply chain security | https://pnpm.io/supply-chain-security | Official | minimumReleaseAge default 1440, allowBuilds, blockExoticSubdeps, trustPolicy | pnpm 11 hardening | S | 2026-09-15 |
| GitHub Changelog: npm install-time security (2026-07-08) | https://github.blog/changelog/2026-07-08-npm-install-time-security-and-gat-bypass2fa-deprecation/ | Official | npm v12 allowScripts off, allow-git/remote none, bypass2fa timeline | Current npm defaults | S | 2026-09-15 |
| npm trusted publishing docs | https://docs.npmjs.com/trusted-publishers/ | Official | Providers, npm 11.5.1+/Node 22.14+, id-token: write, provenance, disallow tokens | Secure publishing | S | 2026-09-15 |
| GitHub blog: secure npm supply chain plan | https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/ | Official | Classic token revocation, 2FA changes | Token roadmap | A | 2026-09-15 |
| Dependabot options reference | https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference | Official | cooldown and groups syntax | Update cooldowns | A | 2026-09-15 |
| OWASP Top 10:2025 | https://top10.owasp.org/2025 | Official | Final 2025 category list (A03 Supply Chain, A10 Exceptional Conditions) | Security taxonomy | S | 2026-09-15 |
| OWASP HTML5 Security Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html | Official | postMessage, storage, CORS, iframe, link rules | Browser security rules (autocomplete=off advice flagged outdated) | A | 2026-09-15 |
| RFC 10017 OAuth 2.0 for Browser-Based Apps (BCP 212) | https://www.rfc-editor.org/info/rfc10017/ | Official | BFF/token-mediating/browser client ranking, PKCE, refresh rotation, DPoP, storage | Authoritative token handling guidance | S | 2026-09-15 |
| web.dev Strict CSP | https://web.dev/articles/strict-csp | Official | Nonce/hash policies, strict-dynamic, rollout, fallbacks | Strict CSP canonical guide | S | 2026-09-15 |
| Next.js CSP guide (16.3.5) | https://nextjs.org/docs/app/guides/content-security-policy | Official | proxy.ts nonce code, dynamic rendering requirement, SRI experimental, dev unsafe-eval | Framework-specific CSP | S | 2026-09-15 |
| Next.js OpenTelemetry guide | https://nextjs.org/docs/app/guides/open-telemetry | Official | @vercel/otel, NodeSDK, default spans, env flags | Server observability | S | 2026-09-15 |
| Next.js instrumentation.js | https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation | Official | register, onRequestError signature/context | Server error reporting | S | 2026-09-15 |
| Next.js instrumentation-client.js | https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client | Official | Client init timing, onRouterTransitionStart, 16.3 event | Client observability | S | 2026-09-15 |
| Next.js Multi-Zones guide | https://nextjs.org/docs/app/guides/multi-zones | Official | assetPrefix, rewrites, cross-zone links, allowedOrigins | Next.js micro-frontends | S | 2026-09-15 |
| next-intl routing setup | https://next-intl.dev/docs/routing/setup | Open Source | defineRouting, proxy.ts, createNavigation, request config, layout | Next.js i18n | A | 2026-09-15 |
| next-intl App Router getting started | https://next-intl.dev/docs/getting-started/app-router | Open Source | Plugin, request config, provider | Next.js i18n | A | 2026-09-15 |
| TC39 Intl.MessageFormat proposal | https://github.com/tc39/proposal-intl-messageformat | Official | Stage 1, stalled | MF2 native status | A | 2026-09-15 |
| Locize: MF2 in i18next (May 2026) | https://www.locize.com/blog/messageformat-2-i18next/ | Community | MF2 CLDR stability, migration state | MF2 adoption context | B | 2026-09-15 |
| Temporal web-features explorer | https://web-platform-dx.github.io/web-features-explorer/features/temporal/ | Official | Baseline blocked by Safari | Date/time API readiness | A | 2026-09-15 |
| Paraglide vs react-i18next | https://paraglidejs.com/paraglide-vs-react-i18next | Community | Compile-time vs runtime tradeoffs | i18n library choice (vendor source) | B | 2026-09-15 |
| OpenFeature React SDK docs | https://openfeature.dev/docs/reference/sdks/client/web/react/ | Official | Provider setup, hooks, suspense, context, test provider | Vendor-neutral flags | S | 2026-09-15 |
| @openfeature/react-sdk npm | https://www.npmjs.com/package/@openfeature/react-sdk | Official | Version 1.4.x | Version currency | A | 2026-09-15 |
| Martin Fowler: Feature Toggles | https://martinfowler.com/articles/feature-toggles.html | Community | Flag taxonomy | Flag lifecycle model | A | 2026-09-15 |
| OpenTelemetry Browser repo | https://github.com/open-telemetry/opentelemetry-browser | Experimental | Event-based browser instrumentations, setup | Browser OTel status | A | 2026-09-15 |
| OpenTelemetry JS docs | https://opentelemetry.io/docs/languages/js/ | Official | Browser instrumentation experimental | Status flag | A | 2026-09-15 |
| Sentry v9 to v10 migration | https://docs.sentry.io/platforms/javascript/migration/v9-to-v10/ | Official | v10 changes, FID removed, OTel 2.x | Monitoring SDK currency | A | 2026-09-15 |
| Announcing TypeScript 7.0 | https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/ | Official | Removed options, new defaults, no API until 7.1, tooling compat | TS config correctness | S | 2026-09-15 |
| typescript-eslint typed linting | https://typescript-eslint.io/getting-started/typed-linting | Official | projectService, presets, defineConfig | Typed lint setup | A | 2026-09-15 |
| Vite 8 announcement | https://vite.dev/blog/announcing-vite8 | Official | Rolldown/Oxc, Node reqs, new options, plugin-react v6 | Build tool currency | S | 2026-09-15 |
| Rsbuild 2.0 announcement | https://rsbuild.rs/blog/v2-0 | Official | Rspack 2, ESM-first, Node 20 | Webpack migration path | A | 2026-09-15 |
| Rspack 2.2 announcement | https://rspack.rs/blog/announcing-2-2 | Official | Current version | Version currency | A | 2026-09-15 |
| ESLint v10.0.0 released | https://eslint.org/blog/2026/02/eslint-v10.0.0-released/ | Official | eslintrc removal, CLI flags removed, Node support | Lint config correctness | S | 2026-09-15 |
| Oxfmt Beta announcement | https://oxc.rs/blog/2026-02-24-oxfmt-beta | Official | Prettier conformance, speed, adopters | Formatter options | A | 2026-09-15 |
| Solberg: type-aware linting Biome vs Oxlint | https://www.solberg.is/fast-type-aware-linting | Community | Biome inference vs Oxlint tsgo tradeoffs | Linter choice | B | 2026-09-15 |
| Module Federation 2.0 stable | https://module-federation.io/blog/v2-stable-version | Official | Runtime decoupling, bundler support | MF currency | A | 2026-09-15 |
| module-federation/core issue #3153 | https://github.com/module-federation/core/issues/3153 | Deprecated | nextjs-mf EOL, App Router unsupported | Prevents adopting dead path | A | 2026-09-15 |
| nextjs-mf package README | https://github.com/module-federation/core/tree/main/packages/nextjs-mf | Deprecated | "Maintenance mode" notice | Confirms status | A | 2026-09-15 |
| Martin Fowler: Micro Frontends | https://martinfowler.com/articles/micro-frontends.html | Community | Integration approaches, communication, downsides | Foundational reasoning | A | 2026-09-15 |
| single-spa recommended setup | https://single-spa.js.org/docs/recommended-setup/ | Open Source | Import maps approach | Brownfield option | B | 2026-09-15 |
| EightShapes team models | https://medium.com/eightshapes-llc/team-models-for-scaling-a-design-system-2cf9d03be6a0 | Community | Solitary/centralized/federated models | Governance models | A | 2026-09-15 |
| EightShapes: Defining contributions | https://eightshapes.com/articles/defining-contributions/ | Community | Contribution sizing | Contribution workflow | A | 2026-09-15 |
| Brad Frost: Atomic Design | https://atomicdesign.bradfrost.com/ | Community | Layered mental model | DS vocabulary | A | 2026-09-15 |
| MDN Trusted Types API | https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API | Official | API and directives | DOM XSS defense | S | 2026-09-15 |
| URIports: CSP Trusted Types | https://www.uriports.com/blog/csp-trusted-types/ | Community | Baseline timeline (Firefox Feb 2026, Safari 26) | Support status | B | 2026-09-15 |
| MDN HTML Sanitizer API | https://developer.mozilla.org/en-US/docs/Web/API/HTML_Sanitizer_API | Official | setHTML, limited availability | Native sanitization | A | 2026-09-15 |
| openapi-fetch docs | https://openapi-ts.dev/openapi-fetch/ | Open Source | createClient, typed calls, {data,error} | API layer typing | A | 2026-09-15 |
| Socket: pnpm 11 defaults | https://socket.dev/blog/pnpm-11-adds-new-supply-chain-protection-defaults | Community | Mini Shai-Hulud context | Threat context (vendor) | B | 2026-09-15 |
| addyosmani/agent-skills frontend-ui-engineering SKILL.md | https://github.com/addyosmani/agent-skills/blob/main/skills/frontend-ui-engineering/SKILL.md | Community | Surveyed agent-skill structure/checklist style (not copied) | Informs AI Agent Guidance format | C | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Feature/layered folder architecture | Feature-Sliced Design docs | Generic "feature folders", eslint-plugin-boundaries guides | feature-based-architecture |
| Module boundary enforcement | Nx enforce-module-boundaries | Turborepo boundaries (experimental), eslint-plugin-boundaries, Steiger | monorepo-frontend-architecture (tools), feature-based-architecture (in-app) |
| Strict CSP | web.dev Strict CSP | Next.js CSP guide, MDN CSP reference | content-security-policy |
| Trusted Types / Sanitizer API | MDN Trusted Types API | URIports blog, Sanitizer API articles | frontend-security-fundamentals (policy), content-security-policy (headers) |
| Browser OAuth token storage | RFC 10017 | OWASP HTML5 cheat sheet storage guidance, IETF drafts | frontend-auth-token-handling |
| Server error reporting in Next.js | Next.js instrumentation.js docs | Sentry Next.js guide | frontend-observability (pipeline), frontend-error-handling-architecture (policy) |
| npm install-time hardening | pnpm supply chain docs + GitHub npm changelog | Community hardening blogs (nodejs-security, dev.to) | dependency-supply-chain-security |
| Flag taxonomy | Martin Fowler/Pete Hodgson Feature Toggles | Vendor docs | feature-flags-and-experimentation |
| Micro-frontend integration models | Martin Fowler Micro Frontends | 2026 community guides | micro-frontends |

## Gaps

- Search budget was exhausted mid-research; these were not independently verified from official pages and are flagged "verify" in skills: typescript-eslint's official TS 7 support range; npm v12 general availability date; exact Vite 8 Rolldown-native option names (e.g., chunking options) and rollup-plugin-visualizer compatibility; pnpm 11 `allowBuilds` exact shape; tsup maintenance status vs tsdown; Auth.js v5 stable status; Storybook current major; Base UI package name; eslint-plugin-react-hooks flat config export names; Next.js 16 `next lint` removal details and Turbopack bundle analyzer support.
- Module Federation Vite plugin (`@module-federation/vite`) maturity with Vite 8 not verified.
- Vercel Flags SDK (`flags` package) API not fetched; mentioned only as an option.
- Next.js taint APIs and `authInterrupts` (`forbidden()`/`unauthorized()`) stability not re-verified for 16.3.
- No dedicated coverage of passkeys/WebAuthn implementation (touches W07 otp-and-auth-forms and W09 authentication-ux); consider a future `passkeys-webauthn` skill.
- No dedicated skill for Architecture Decision Records or "architecture fitness functions" (currently embedded in frontend-architecture-principles).
- Community-authored agent rules (.cursor/rules, AGENTS.md) for architecture/security were surveyed only lightly; W17 may deepen.
- Experimentation statistics (sequential testing, CUPED, SRM math) intentionally kept shallow.
