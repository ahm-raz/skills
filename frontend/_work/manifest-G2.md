# Manifest: G2 Gap Pass 2 (accessibility, auth, device performance)

Last Verified: 2026-09-15. WebSearch unavailable; all research via WebFetch against official/known URLs.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| reflow-zoom-and-text-spacing | Reflow, Zoom, and Text Spacing | Accessibility | React, Next.js | A | Active | https://www.w3.org/WAI/WCAG22/Understanding/reflow.html |
| passkeys-and-webauthn | Passkeys and WebAuthn | Security | React, Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API |
| low-end-device-performance | Low-End Device Performance | Performance | React, Next.js | A | Active | https://infrequently.org/2025/11/performance-inequality-gap-2026/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Understanding SC 1.4.10 Reflow | https://www.w3.org/WAI/WCAG22/Understanding/reflow.html | Official | 320/256 CSS px, 2D exceptions, F102, C31/C32/C33 | Normative intent for reflow | S | 2026-09-15 |
| Understanding SC 1.4.4 Resize Text | https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html | Official | 200% rule, exceptions, failures | Defines text resize requirement | S | 2026-09-15 |
| Understanding SC 1.4.12 Text Spacing | https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html | Official | Four spacing metrics, failure modes | Test values | S | 2026-09-15 |
| Understanding SC 1.4.13 Content on Hover or Focus | https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html | Official | Dismissible/hoverable/persistent, title exception | Tooltip/popover requirements | S | 2026-09-15 |
| WCAG Technique C36 | https://www.w3.org/WAI/WCAG22/Techniques/css/C36 | Official | Avoid fixed heights; bookmarklet test procedure | Test method for 1.4.12 | S | 2026-09-15 |
| Next.js generateViewport | https://nextjs.org/docs/app/api-reference/functions/generate-viewport | Official | Default viewport, Viewport fields (v16.3.5) | Prevent zoom-blocking config | S | 2026-09-15 |
| Tailwind CSS font-size | https://tailwindcss.com/docs/font-size | Official | rem sizes, text-size/line-height syntax | Tailwind v4 implications | A | 2026-09-15 |
| MDN Web Authentication API | https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API | Official | Ceremonies, JSON helpers, getClientCapabilities, Signal API, RP ID | Platform reference | S | 2026-09-15 |
| web.dev passkey form autofill | https://web.dev/articles/passkey-form-autofill | Official | Conditional mediation, AbortController, Signal API, upgrade prompts | Sign-in UX pattern | S | 2026-09-15 |
| web.dev passkey registration | https://web.dev/articles/passkey-registration | Official | Registration options, random user ID, stored fields | Registration correctness | S | 2026-09-15 |
| passkeys.dev Related Origins | https://passkeys.dev/docs/advanced/related-origins/ | Official | .well-known/webauthn format, 5-label limit | Multi-domain passkeys | A | 2026-09-15 |
| passkeys.dev Bootstrapping | https://passkeys.dev/docs/use-cases/bootstrapping/ | Official | Conditional UI flow, fallback, UV preferred, cross-device enrollment | Flow design | A | 2026-09-15 |
| SimpleWebAuthn server | https://simplewebauthn.dev/docs/packages/server | Open Source | v14 API, registrationInfo.credential, DB fields | Server verification library | A | 2026-09-15 |
| SimpleWebAuthn browser | https://simplewebauthn.dev/docs/packages/browser | Open Source | startRegistration/startAuthentication, useBrowserAutofill, WebAuthnError | Client ceremony | A | 2026-09-15 |
| Better Auth passkey plugin | https://www.better-auth.com/docs/plugins/passkey | Open Source | @better-auth/passkey, config, autoFill | Managed option | A | 2026-09-15 |
| Auth.js WebAuthn | https://authjs.dev/getting-started/authentication/webauthn | Open Source | Experimental status, requirements | Avoid for production | B | 2026-09-15 |
| Clerk passkeys custom flow | https://clerk.com/docs/guides/development/custom-flows/authentication/passkeys | Vendor | createPasskey, authenticateWithPasskey, domain limits | Managed option | A | 2026-09-15 |
| Passkey Central required patterns | https://www.passkeycentral.org/design-guidelines/required-patterns/ | Official (FIDO) | Two required patterns (manage, sign-in with fallback) | UX baseline | B (overview only) | 2026-09-15 |
| Performance Inequality Gap 2026 | https://infrequently.org/2025/11/performance-inequality-gap-2026/ | Community/Expert | P75 devices, 9/3 Mbps 100ms, 3s/5s budgets | Device-class budgets | A | 2026-09-15 |
| Performance Inequality Gap 2024 | https://infrequently.org/2024/01/performance-inequality-gap-2024/ | Community/Expert | Prior baseline, JS cost rationale | Historical comparison | B | 2026-09-15 |
| web.dev Adaptive loading | https://web.dev/articles/adaptive-loading-cds-2019 | Official | Signals, react-adaptive-hooks, tiering examples | Adaptive loading concept | B (2019) | 2026-09-15 |
| web.dev Save-Data | https://web.dev/articles/optimizing-content-efficiency-save-data | Official | Header/JS detection, adaptations, Vary | Data-saver handling | B (older article) | 2026-09-15 |
| web.dev Optimize INP | https://web.dev/articles/optimize-inp | Official | Yielding, input delay, DOM size, 200ms | INP on slow CPUs | S | 2026-09-15 |
| MDN Navigator.deviceMemory | https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory | Official | Coarse values, HTTPS, limited support | Signal reliability | S | 2026-09-15 |
| MDN Network Information API | https://developer.mozilla.org/en-US/docs/Web/API/Network_Information_API | Official | Properties, change event, not Baseline | Signal reliability | S | 2026-09-15 |
| MDN Sec-CH-Device-Memory | https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-CH-Device-Memory | Official | Accept-CH opt-in, experimental | Server hints | A | 2026-09-15 |
| Chrome DevTools Performance reference | https://developer.chrome.com/docs/devtools/performance/reference | Official | CPU calibration, CrUX throttling guidance, emulation limits | Honest lab throttling | S | 2026-09-15 |
| Chrome DevTools Throttling | https://developer.chrome.com/docs/devtools/settings/throttling | Official | Calibrated presets, custom network profiles | Throttling setup | A | 2026-09-15 |
| Next.js Lazy loading guide | https://nextjs.org/docs/app/guides/lazy-loading | Official | next/dynamic, ssr:false constraints (v16.3.5) | Reducing client JS | S | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Conditional UI / passkey autofill | web.dev passkey-form-autofill | passkeys.dev bootstrapping, MDN WebAuthn, SimpleWebAuthn browser docs | passkeys-and-webauthn |
| Registration option recommendations | web.dev passkey-registration | passkeys.dev bootstrapping (UV preferred), SimpleWebAuthn server docs | passkeys-and-webauthn |
| Device budgets | Performance Inequality Gap 2026 | 2024 edition | low-end-device-performance |
| Capability signals | MDN deviceMemory / Network Information | web.dev adaptive loading, web.dev Save-Data, MDN Sec-CH-Device-Memory | low-end-device-performance |
| Zoom/reflow/spacing criteria | W3C Understanding docs (1.4.4/1.4.10/1.4.12/1.4.13) | Technique C36 | reflow-zoom-and-text-spacing |

## Gaps
- TPGi reflow article returned 403 and the Adrian Roselli zoom article URL returned 404, so no practitioner articles were used for reflow. Deque content wasn't attempted because WebSearch was unavailable to find URLs.
- The CSS injected by the Text Spacing Bookmarklet (Steve Faulkner, CodePen) wasn't verified. The Playwright snippet uses WCAG's metric values instead.
- Passkey Central (FIDO) detailed pattern pages (wording, icon, recovery specifics) weren't fetched; only the overview and required-patterns pages were.
- The TypeScript DOM lib typing for the Signal API (`signalUnknownCredential`) wasn't verified. The example uses `@ts-expect-error`.
- The SimpleWebAuthn v14 `userID` option type and the `@simplewebauthn/server/helpers` export path come from memory of v10+ APIs: Check current docs.
- WebPageTest docs (docs.webpagetest.org) failed with a TLS certificate error. Real-device availability and profiles are marked "Check current docs".
- Lighthouse mobile throttling constants (4x CPU) are stated from general knowledge and weren't re-verified.
- Auth.js docs still pin SimpleWebAuthn 9.x. Whether v5 has moved beyond experimental is unknown.
- Chrome DevTools preset network values (Slow 4G, Fast 4G) weren't extracted numerically.
