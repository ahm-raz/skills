# Feature Flags and Experimentation

## Summary
How to use feature flags and A/B experiments in React and Next.js without flicker, security leaks, or flag debt. Covers flag types, the OpenFeature vendor-neutral standard (web SDK + React SDK 1.x, server SDK for Next.js), server-side evaluation in Server Components/proxy, client evaluation with Suspense, experiment design basics (assignment, exposure logging, SRM, guardrails), and lifecycle cleanup.

## Category
Architecture

## Subcategories
Release toggles, experiments, kill switches, permission flags, OpenFeature, evaluation context, server-side evaluation, flicker prevention, exposure events, flag debt

## Problem It Solves
Big-bang releases are risky; experiments implemented ad hoc cause UI flicker, inconsistent assignments, analytics bias, leaked unreleased features in client bundles, and hundreds of stale flags. A disciplined flag architecture enables trunk-based development, progressive rollout, safe experiments, and clean removal.

## When To Use
- Progressive rollouts, canaries, beta programs, kill switches for risky integrations.
- A/B/n experiments on UI or pricing.
- Trunk-based development with incomplete features merged behind flags.

## When Not To Use
- Long-term configuration or entitlements that belong in a permissions/billing system (don't model plans as flags forever).
- Security-critical authorization — flags can gate UI, but the server must enforce access.
- Tiny apps with no rollout risk: environment config is enough.

## Core Principles
1. **Classify flags by lifespan and purpose** (release, experiment, ops/kill switch, permission) — each has different owners and expiry.
2. **Evaluate as close to the server as possible** to avoid flicker and to keep unreleased code/data off the client.
3. **Vendor-neutral API** (OpenFeature) so providers can change without touching components.
4. **Consistent assignment** via a stable targeting key (user ID or anonymous ID cookie).
5. **Log exposure when the user actually sees the variant**, not when the flag is fetched.
6. **Every flag has an owner and a removal date;** stale flags are debt.
7. **Defaults are safe:** if the provider fails, the default path must be the known-good experience.

## Best Practices
- Flag types (Pete Hodgson/Martin Fowler taxonomy):
  | Type | Lifespan | Dynamism | Example |
  |---|---|---|---|
  | Release toggle | Days–weeks | Per deploy/rollout % | `new-checkout` |
  | Experiment toggle | Weeks | Per user, sticky | `pricing-page-v2` |
  | Ops toggle / kill switch | Long-lived | Instant | `disable-recommendations` |
  | Permission toggle | Long-lived | Per user/segment | `beta-program` |
- Naming: `kebab-case`, purpose-prefixed optional (`exp-`, `ops-`), never reuse names.
- Evaluation context: `targetingKey` (stable ID), plus attributes (plan, country, app version). Do not send PII you don't need to the vendor.
- Next.js: evaluate in Server Components/proxy, pass resolved values (not the whole flag config) to Client Components.
- Static pages + experiments: either precompute variants (route per variant via proxy rewrite with a variant cookie) or accept dynamic rendering. Avoid client-only toggling of above-the-fold content.
- Client flags: bootstrap initial values from the server render to avoid a loading state; then subscribe to changes.
- Keep unreleased features' code out of client bundles when secrecy matters: gate the import (`dynamic()`/`lazy`) on the server-evaluated flag.
- Experiments: pre-register hypothesis, primary metric, guardrail metrics (errors, LCP/INP, revenue), sample size; check Sample Ratio Mismatch (SRM); don't peek and stop early without sequential methods.
- Cleanup: lint or scan for flag keys; alert on flags at 100% for > N days; removal PR removes code and flag config together.

## Implementation Guidance

### OpenFeature in a Vite React SPA
```tsx
// main.tsx
import { OpenFeature, OpenFeatureProvider } from '@openfeature/react-sdk';
import { VendorWebProvider } from '@vendor/openfeature-web-provider'; // any web-compatible provider

await OpenFeature.setContext({ targetingKey: anonymousId(), plan: 'free' });
OpenFeature.setProvider(new VendorWebProvider({ clientKey: import.meta.env.VITE_FLAGS_CLIENT_KEY })); // client keys are public by design

createRoot(document.getElementById('root')!).render(
  <OpenFeatureProvider suspendUntilReady>
    <Suspense fallback={<AppSkeleton />}><App /></Suspense>
  </OpenFeatureProvider>,
);
```
```tsx
import { useBooleanFlagValue, useFlag } from '@openfeature/react-sdk';
export function CheckoutButton() {
  const newCheckout = useBooleanFlagValue('new-checkout', false); // default = safe path
  return newCheckout ? <NewCheckoutButton /> : <LegacyCheckoutButton />;
}
// Details (variant, reason) for exposure logging:
const { value, variant, reason } = useFlag('pricing-page-v2', 'control');
```
After login: `await OpenFeature.setContext({ targetingKey: user.id, plan: user.plan })` — components re-render with new evaluations.

### OpenFeature server SDK in Next.js (Server Components)
```ts
// src/shared/flags/server.ts
import 'server-only';
import { OpenFeature } from '@openfeature/server-sdk';
import { VendorServerProvider } from '@vendor/openfeature-server-provider';
let ready: Promise<void> | undefined;
export async function flags() {
  ready ??= OpenFeature.setProviderAndWait(new VendorServerProvider({ sdkKey: process.env.FLAGS_SDK_KEY! }));
  await ready;
  return OpenFeature.getClient();
}
```
```tsx
// app/checkout/page.tsx
import { flags } from '@/shared/flags/server';
import { getSession } from '@/entities/session/server';
import dynamic from 'next/dynamic';
const NewCheckout = dynamic(() => import('@/features/new-checkout'));
const LegacyCheckout = dynamic(() => import('@/features/legacy-checkout'));
export default async function CheckoutPage() {
  const session = await getSession();
  const client = await flags();
  const on = await client.getBooleanValue('new-checkout', false, { targetingKey: session?.userId ?? session?.anonId ?? 'anon' });
  return on ? <NewCheckout /> : <LegacyCheckout />;
}
```

### Experiment on a static page via proxy rewrite (no flicker, CDN-cacheable)
```ts
// src/proxy.ts
import { NextResponse, type NextRequest } from 'next/server';
export function proxy(req: NextRequest) {
  if (req.nextUrl.pathname !== '/pricing') return;
  let variant = req.cookies.get('exp-pricing')?.value;
  if (variant !== 'a' && variant !== 'b') variant = Math.random() < 0.5 ? 'a' : 'b'; // or hash(anonId) for determinism
  const res = NextResponse.rewrite(new URL(`/pricing/${variant}`, req.url));
  res.cookies.set('exp-pricing', variant, { path: '/', maxAge: 60 * 60 * 24 * 30, sameSite: 'lax', secure: true });
  return res;
}
export const config = { matcher: ['/pricing'] };
```
Pages `app/pricing/[variant]/page.tsx` with `generateStaticParams` returning `a` and `b`; log exposure client-side when the variant renders.

### Exposure logging
```tsx
'use client';
import { useEffect } from 'react';
export function ExposureLogger({ experiment, variant }: { experiment: string; variant: string }) {
  useEffect(() => { analytics.track('experiment_exposure', { experiment, variant }); }, [experiment, variant]);
  return null;
}
```

### Testing with OpenFeature
```tsx
import { OpenFeatureTestProvider } from '@openfeature/react-sdk';
render(<OpenFeatureTestProvider flagValueMap={{ 'new-checkout': true }}><CheckoutButton /></OpenFeatureTestProvider>);
```

## Recommended Workflow
1. Create flag with type, owner, description, expiry date, and default (safe) value.
2. Implement both paths behind the flag; evaluate server-side where possible.
3. Test both variants (unit + E2E with forced flag values).
4. Roll out: internal -> % rollout -> 100%, watching guardrail metrics.
5. For experiments: define metrics, run to planned sample size, check SRM, decide.
6. Remove the flag: delete losing code path and flag config in one PR.

## Patterns
- **Server-evaluated, client-hydrated flags:** resolve in RSC, pass booleans as props.
- **Kill switch wrapper:** `if (!(await flags()).getBooleanValue('ops-recs', true)) return null`.
- **Variant route rewrite** for static experiments.
- **Flag registry file** (`flags.ts`) listing keys, types, owners, expiry — imported everywhere instead of string literals.
- **Domain-scoped providers** (OpenFeature `domain`) for separate flag systems.

## Anti-Patterns
- **Client-only evaluation of above-the-fold UI** — flicker, CLS, biased results. Fix: server evaluation or bootstrap values.
- **Flags as authorization** — users can flip client flags. Fix: server-side enforcement.
- **String literals scattered** — impossible cleanup. Fix: typed registry.
- **Logging exposure on evaluation** — dilutes experiment. Fix: log when rendered/seen.
- **Nested flag conditions** (`if (a && !b && c)`) — untestable combinatorics. Fix: one flag per decision; retire quickly.
- **Unsafe defaults** (new feature on when provider fails) — Fix: default to known-good.
- **Shipping unreleased feature code/data to all clients** — leaks. Fix: server gate + dynamic import.
- **Math.random per render for assignment** — inconsistent UX. Fix: sticky cookie or hash of stable ID.

## Accessibility
- Every variant must meet WCAG 2.2 AA; include accessibility checks in experiment QA (a failing variant biases results and harms users).
- Avoid layout shifts from late flag resolution (also a WCAG 2.2 predictability concern for focus and reading position).

## Responsive Design
- Test variants at all breakpoints; experiments often break mobile layouts that weren't in the design.

## Performance
- Server-side evaluation avoids client SDK round trips and flicker; client SDKs add bundle weight (check size) and network calls — bootstrap and cache.
- Include LCP/INP/CLS as guardrail metrics; variant-specific regressions invalidate wins.
- Dynamic rendering for per-user flags removes CDN caching — prefer precomputed variants for high-traffic static pages.

## Security
- Client-side SDK keys are public; never use server SDK keys in client code (`NEXT_PUBLIC_`/`VITE_`).
- Evaluation context sent to vendors: minimize PII, use hashed IDs.
- Enforce entitlements server-side regardless of flag state.

## Testing
- Unit/component: force variants via `OpenFeatureTestProvider` or in-memory provider.
- E2E: set variant cookies or query overrides (guarded to non-production) to test each path.
- Contract: CI check that all flag keys in code exist in the registry and none are past expiry.

## Tooling
- OpenFeature (spec, `@openfeature/web-sdk`, `@openfeature/react-sdk` 1.x, `@openfeature/server-sdk`) — Active (CNCF).
- flagd (OpenFeature reference flag daemon) — Active.
- Vendor providers: LaunchDarkly, Statsig, Split/Harness, ConfigCat, DevCycle, Flagsmith, Unleash, GrowthBook, PostHog — Commercial/Open core with OpenFeature providers (verify provider maturity).
- Vercel Flags SDK (`flags` package) — Active, Next.js-oriented (server-evaluated flags, precompute pattern); verify current API.
- GrowthBook / Eppo / Statsig — experimentation stats engines.

## Framework Notes
- **React (Vite SPA):** all evaluation is client-side; bootstrap from an edge/BFF response or local cache to avoid flicker; use `suspendUntilReady` with a skeleton for critical flags; secret features cannot be hidden from determined users — keep sensitive data behind server APIs.
- **Next.js App Router:** evaluate in Server Components or `proxy.ts`; reading cookies/headers makes routes dynamic — use proxy rewrites to static variant routes for cacheable experiments; pass resolved values to `'use client'` components; don't initialize client flag SDKs in Server Components. Clear `generateStaticParams` for variant segments.

## AI Agent Guidance
- Look for the flag registry and existing OpenFeature setup before adding a flag.
- Do: add flag to registry with owner/expiry; default to the safe path; evaluate server-side in Next.js; add tests for both variants.
- Don't: evaluate critical-UI flags only on the client, use flags for authorization, or leave dead variant code after rollout.
- Verify: both variants render without hydration warnings or CLS; tests force each variant; flag removal ticket created.

## Examples
```ts
// shared/flags/registry.ts
export const FLAGS = {
  'new-checkout': { type: 'release', owner: 'team-payments', expires: '2026-11-01', default: false },
  'ops-recommendations': { type: 'ops', owner: 'team-discovery', expires: null, default: true },
  'exp-pricing-page': { type: 'experiment', owner: 'team-growth', expires: '2026-10-15', default: 'control' },
} as const;
export type FlagKey = keyof typeof FLAGS;
```

## Related Skills
- [frontend-observability](../frontend-observability/Skill.md) — exposure and guardrail metrics
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — variant rewrites
- [nextjs-rendering-strategies](../nextjs-rendering-strategies/Skill.md) — static vs dynamic tradeoffs
- [cls-prevention](../cls-prevention/Skill.md) — avoiding flicker shifts
- [conversion-ux](../conversion-ux/Skill.md) — experiment design context
- [frontend-architecture-principles](../frontend-architecture-principles/Skill.md) — single integration point

## Sources
- [OpenFeature React SDK](https://openfeature.dev/docs/reference/sdks/client/web/react/) — Official — providers, hooks, suspense, testing
- [OpenFeature specification](https://openfeature.dev/specification/) — Official — evaluation API, context
- [@openfeature/react-sdk on npm](https://www.npmjs.com/package/@openfeature/react-sdk) — Official — version 1.x
- [Martin Fowler / Pete Hodgson: Feature Toggles](https://martinfowler.com/articles/feature-toggles.html) — Community (respected) — flag taxonomy
- [Next.js proxy file convention](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) — Official — rewrites
- [Flags SDK](https://flags-sdk.dev) — Open Source — Next.js flag patterns (verify)

## License / Usage Notes
OpenFeature is Apache-2.0; summarized. Fowler article paraphrased. Vendor names are examples, not endorsements.

## Quality Tier
A — official OpenFeature docs and Next.js conventions; statistics guidance is intentionally brief (defer to experimentation platform docs).

## Status
Active

## Last Verified
2026-09-15
