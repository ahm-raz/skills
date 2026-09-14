# React Server Components

## Summary
React Server Components (RSC) run only on the server, or at build time. They can be `async`, read data directly, and send a serialized UI payload with zero client JavaScript. Client Components (`"use client"`) add interactivity, and Server Functions (`"use server"`) let clients call server code. This skill covers the framework-agnostic model: boundaries, serialization rules, composition, data flow, caching with `cache`/`cacheSignal`, and the critical security posture after the December 2025 RSC CVEs.

## Category
React

## Subcategories
server/client boundary, "use client", "use server", Server Functions, serialization, cache(), cacheSignal, server-only, taint APIs, streaming, RSC security

## Problem It Solves
- Shipping data-fetching code, heavy libraries and secrets to the browser.
- Client-server waterfalls.
- Bloated bundles from components that are never interactive.

RSC moves non-interactive rendering and data access to the server. Used carelessly, it also creates new risks: leaked secrets, over-serialization, and unauthenticated server endpoints.

## When To Use
- Next.js App Router apps, which are the production-grade RSC implementation in this stack.
- Content-heavy pages, dashboards with server data, pages with heavy rendering dependencies (markdown, syntax highlighting, date libs).

## When Not To Use
- Pure client SPAs with no server runtime (plain Vite apps, embedded widgets).
- Highly interactive, real-time surfaces (editors, canvases): mostly Client Components, perhaps with an RSC shell.
- Don't hand-roll RSC bundler integration for production. Use a framework.

## Core Principles
1. **Server by default, client by exception.** Push `"use client"` to the leaves (buttons, forms, charts), not the layout.
2. **`"use client"` marks a module boundary.** Everything imported from that file becomes client code. Server Components are not "components without hooks"; they are a different module graph.
3. **Props crossing server → client must be serializable**: primitives, plain objects/arrays, Date, Map, Set, BigInt, typed arrays, Promises, JSX, and Server Function references. Not class instances or arbitrary functions.
4. **Server Components can pass Server Components as `children`/props to Client Components**, but Client Components can't import Server Components.
5. **`"use server"` creates a public HTTP endpoint.** Every Server Function must authenticate, authorize and validate input as if it were an API route.
6. **Fetch where you render, deduplicate with `cache()`**, and parallelize independent requests.
7. **Minimize what crosses the boundary.** Send only the fields the client needs.

## Best Practices
- Mark server-only modules with `import "server-only"` (build error if imported by client code). Use `client-only` for the reverse.
- Keep secrets in server env vars and never pass them as props. Consider `experimental_taintObjectReference`/`taintUniqueValue` where the framework supports them.
- Wrap data access functions in `cache()` for per-request memoization across the tree.
- Use `cacheSignal()` (19.2+) to abort work when the render that needed a cached request is abandoned.
- Start promises early and await late. Pass un-awaited promises to Client Components and unwrap with `use()` inside Suspense, to stream without blocking the shell.
- Render context providers in a Client Component. In React 19.3, Server Components can render a client-created Context directly (`<UserContext value={user}>`) without a wrapper provider component.
- **Patch immediately**: CVE-2025-55182 (unauthenticated RCE, CVSS 10.0) plus follow-ups (CVE-2025-55183 source exposure, CVE-2025-55184/67779/CVE-2026-23864 DoS) affected `react-server-dom-*` 19.0–19.2.0. Stay on the latest 19.x patch and the latest framework patch.

## Implementation Guidance
**Server or Client Component?**

| Needs | Component |
|---|---|
| Direct DB/filesystem/secret access | Server |
| Large dependencies used only for markup | Server |
| `useState`, `useEffect`, event handlers | Client |
| Browser APIs (`window`, `localStorage`) | Client |
| Context consumers | Client |
| Static markup inside an interactive shell | Server, passed as `children` |

**Boundary layout**
```
app/products/[id]/page.tsx      (Server) fetch product, render layout
  ├─ ProductGallery.tsx          (Server) images markup
  ├─ AddToCartButton.tsx         "use client": onClick, optimistic state
  └─ Reviews.tsx                 (Server, async, inside <Suspense>)
```

**Data access layer**
```ts
// data/products.ts
import "server-only";
import { cache } from "react";

export const getProduct = cache(async (id: string) => {
  const row = await db.product.findUnique({ where: { id } });
  if (!row) return null;
  // DTO: only public fields
  return { id: row.id, name: row.name, priceCents: row.priceCents, imageUrl: row.imageUrl };
});
```

**Streaming a promise to a client component**
```tsx
// page.tsx (Server)
export default async function Page({ id }: { id: string }) {
  const product = await getProduct(id);               // needed for shell
  const reviewsPromise = getReviews(id);              // not awaited
  return (
    <>
      <h1>{product?.name}</h1>
      <Suspense fallback={<ReviewsSkeleton />}>
        <ReviewList reviews={reviewsPromise} />
      </Suspense>
    </>
  );
}
// ReviewList.tsx
"use client";
import { use } from "react";
export function ReviewList({ reviews }: { reviews: Promise<Review[]> }) {
  const list = use(reviews);
  return <ul>{list.map(r => <li key={r.id}>{r.text}</li>)}</ul>;
}
```

**Server Function, secured**
```ts
"use server";
import { z } from "zod";
const Input = z.object({ productId: z.string().uuid(), qty: z.number().int().min(1).max(99) });

export async function addToCart(raw: unknown) {
  const session = await getSession();                  // authN
  if (!session) throw new Error("Unauthorized");
  const { productId, qty } = Input.parse(raw);         // validate
  await assertCanPurchase(session.userId, productId);  // authZ
  await cartRepo.add(session.userId, productId, qty);
  return { ok: true as const };
}
```

## Recommended Workflow
1. Draw the route tree. Mark interactive leaves as Client Components.
2. Build a server-only data access layer that returns DTOs. Wrap it with `cache()`.
3. Fetch in Server Components. Parallelize with `Promise.all` or separate Suspense boundaries.
4. Add Suspense boundaries around slow sections so the shell streams quickly.
5. Implement mutations as Server Functions with auth, validation and revalidation.
6. Audit the client bundle (framework analyzer) and the RSC payload size.
7. Audit `"use server"` exports: each is reachable by anyone.

## Patterns
- **Client island with server children**: `<Tabs>{serverRenderedPanels}</Tabs>`.
- **Data Access Layer + DTO**: centralize authorization in server-only modules.
- **Preload pattern**: `void getUser(id)` early to start the fetch, then call again where needed (deduplicated via `cache`).
- **Promise-as-prop streaming**: avoid awaiting non-critical data in the parent.
- **Server Function passed as prop/form action**: `<form action={addToCart}>`.

## Anti-Patterns
- **`"use client"` at the layout or page root**: the whole subtree ships JS. Fix: move it to the smallest interactive leaf.
- **Passing whole ORM rows to Client Components**: leaks fields (hashed passwords, internal flags) and bloats the payload. Fix: DTOs.
- **Unauthenticated Server Functions** ("it's only called from my admin page"): they are public endpoints. Fix: auth in every function.
- **Sequential awaits for independent data**: waterfall. Fix: `Promise.all` or parallel Suspense subtrees.
- **Module-level mutable state in server modules**: shared across requests and users. Fix: per-request `cache()` or request context.
- **Importing server code into client files**: bundle leaks or build errors. Fix: `server-only`, and split modules.
- **Creating promises inside Client Components and passing them to `use()`**: new promise every render, infinite suspend. Fix: create in a Server Component, loader or cache.
- **Running unpatched `react-server-dom-*`**: RCE exposure. Fix: upgrade and pin to patched versions.

## Accessibility
- Server-rendered HTML gives screen readers content before hydration. Keep semantic HTML in Server Components.
- Interactive Client Components must work (or degrade gracefully) before hydration. Forms with Server Function `action` submit even without JS in supporting frameworks (progressive enhancement).
- Suspense fallbacks should be announced sensibly (skeletons with `aria-busy`, not endless spinners).

## Responsive Design
- Server Components don't know the viewport. Use CSS for responsive layout and responsive images (`srcset`/`sizes`).
- Avoid user-agent sniffing for layout. It breaks caching and resizable windows.

## Performance
- Zero client JS for Server Components. Heavy dependencies (markdown parsers, syntax highlighters) stay on the server.
- Watch the RSC payload: large props are serialized twice (HTML plus the Flight payload). Pass minimal data.
- Stream with Suspense to improve TTFB/LCP. Keep above-the-fold content out of slow boundaries.
- Deduplicate requests with `cache()`. Use cross-request caching (framework cache or LRU) deliberately.

## Security
- Treat every `"use server"` function as a public POST endpoint: authN, authZ, input validation (Zod/Valibot), rate limiting, CSRF protections as provided by the framework.
- Keep React and framework packages on patched versions (Dec 2025 – Jan 2026 CVEs: RCE, DoS, source code exposure).
- Never interpolate secrets into Client Component props. Use `server-only`. Review error messages so they don't leak internals (production errors are redacted with a digest).
- Validate the closure variables of inline Server Functions. Captured values are encrypted or bound by frameworks, but arguments are attacker-controlled.

## Testing
- Unit test the data access layer and Server Functions as plain async functions (Vitest, with DB test containers or mocks).
- Async Server Components have limited unit-test support. Prefer framework integration or e2e tests (Playwright) for pages.
- Test Server Functions for unauthorized and invalid-input cases.
- Snapshot RSC payload size and bundle size in CI where possible.

## Tooling
- Next.js App Router (16.x): the RSC implementation for this stack.
- `@vitejs/plugin-rsc` exists but is a low-level integration. Don't use it for app teams on this stack.
- `server-only` / `client-only` packages.
- Zod / Valibot for Server Function input validation.

## Framework Notes
### React (Vite SPA)
- There are no Server Components. The equivalent split is: a server or API (tRPC, REST, BFF) owns data access and secrets, and the SPA fetches with TanStack Query.
- Everything in the SPA bundle is public, so apply the same "DTO only" rule to API responses.

### Next.js App Router
- Every file under `app/` is a Server Component unless its module (or an importing client module) has `"use client"`. `page.tsx`, `layout.tsx` and `not-found.tsx` can be async Server Components. `error.tsx` must be a Client Component.
- **Server Actions are Server Functions.** `"use server"` at the top of `actions.ts`, or inline inside an async function in a Server Component. Call `revalidatePath`/`revalidateTag` after mutations, and never catch the `redirect()`/`notFound()` errors they throw (or rethrow with `unstable_rethrow`).
- `React.cache` deduplicates within one request. Cross-request caching belongs to Next.js (`fetch` cache options, and the `"use cache"` directive with Cache Components in Next.js 16). See nextjs-caching-and-revalidation.
- Only `NEXT_PUBLIC_*` env vars reach the client bundle. Everything else is server-only, but a Server Component can still leak it by passing it as a prop.
- `params` and `searchParams` are Promises in Next.js 15+ (`const { id } = await params`).
- Hydration: Client Components receive props serialized in the RSC payload. Any mismatch between server HTML and the first client render throws a recoverable hydration error that re-renders on the client.
- Keep `next` and `react`/`react-dom` on the latest patch. The Dec 2025 RSC CVEs required coordinated Next.js patch releases.

## AI Agent Guidance
- Default new files to Server Components in RSC apps. Add `"use client"` only when hooks, handlers or browser APIs are needed.
- For every `"use server"` function you write: auth check, schema validation, authorization, minimal return value.
- Never pass DB rows, env vars or tokens as props. Create DTOs.
- Check `react-server-dom-*` and framework versions for known CVEs before shipping.
- Verify: build passes with `server-only` guards, no client bundle includes server libs, and pages stream with sensible Suspense fallbacks.

## Examples
```tsx
// React 19.3: Server Component rendering a client Context directly
// user-context.ts
"use client";
import { createContext } from "react";
export const UserContext = createContext<{ id: string; name: string } | null>(null);

// layout.tsx (Server)
import { UserContext } from "./user-context";
export default async function Layout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUserDTO();
  return <UserContext value={user}>{children}</UserContext>;
}
```

## Related Skills
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md): Next.js-specific RSC patterns
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): Server Functions in Next.js
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md): client side of Actions
- [react-suspense-and-error-boundaries](../react-suspense-and-error-boundaries/Skill.md): streaming boundaries
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md): endpoint security
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md): patching RSC CVEs

## Sources
- [react.dev: Server Components](https://react.dev/reference/rsc/server-components) (Official): model, async components
- [react.dev: 'use client' / 'use server' directives](https://react.dev/reference/rsc/use-client) (Official): boundary and serialization rules
- [react.dev: cache / cacheSignal](https://react.dev/reference/react/cache) (Official): per-request memoization
- [Critical Security Vulnerability in RSC (Dec 3 2025)](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components) (Official): CVE-2025-55182 and follow-ups
- [React 19.3 post](https://react.dev/blog/2026/09/09/react-19-3) (Official): direct context rendering from RSC
- [vercel-labs agent-skills react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) (Community/Open Source): server-* rules (auth actions, serialization, dedup, no shared module state)
- [Next.js docs: Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components) (Official): App Router boundary rules, interleaving

## License / Usage Notes
React docs are CC-BY-4.0/MIT. Vercel agent-skills is MIT. This is a summary with original code.

## Quality Tier
A: official, and includes current CVE posture; framework RSC support outside Next.js is still moving and needs periodic re-verification.

## Status
Active

## Last Verified
2026-09-15
