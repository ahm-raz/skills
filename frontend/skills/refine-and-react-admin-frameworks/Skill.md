# refine and react-admin Frameworks

## Summary
refine and react-admin are two open-source React frameworks for CRUD-heavy admin apps. Both are built around providers (data, auth, access control) and resources. refine is headless and has a Next.js router integration. react-admin is Material UI–based and runs as a client-side SPA, which in Next.js means mounting it client-only. This skill covers when to choose each (or neither), how to wire them into Next.js App Router or Vite, and how to keep authorization on the server.

## Category
Enterprise UI

## Subcategories
Admin frameworks, data providers, auth providers, access control providers, CRUD scaffolding, Next.js integration

## Problem It Solves
Hand-building list, show, edit and create screens for dozens of resources is repetitive: pagination, sorting, filters, optimistic updates, cache invalidation, notifications, permissions. These frameworks standardize that work behind a provider contract, so each new resource is mostly configuration.

## When To Use
- Many CRUD resources on top of an existing REST/GraphQL/Supabase/etc. API.
- A team wants conventions (resources, hooks, providers) rather than an architecture of its own.
- **refine:** you need a custom design system (headless) or a Next.js router integration, or you use Ant Design, MUI, Chakra or Mantine.
- **react-admin:** Material UI is acceptable, you want a very large set of ready components (Datagrid, filters, reference inputs) and an SPA is fine.

## When Not To Use
- The app is mostly bespoke workflows, with few generic CRUD screens.
- You want Server Components and Server Actions as the primary data path. Both frameworks are client-centric; hand-rolled App Router fits better (see [admin-panel-architecture](../admin-panel-architecture/Skill.md)).
- Public or SEO pages.
- You'd be fighting the provider contract (e.g., a highly non-CRUD RPC backend).

## Core Principles
1. **Providers are adapters, not security.** Data, auth and access-control providers run in the browser. The backend API must enforce authz and tenant scoping.
2. **Resources are the unit of configuration.** Name, routes, meta (label, icon, permissions) drive nav, breadcrumbs and access checks.
3. **Speak one list contract.** Map the framework's pagination/sorters/filters shape to your API in one place, the data provider.
4. **Client framework, server boundary.** In Next.js, keep secrets in Route Handlers or a backend-for-frontend proxy, never in the provider.
5. **Pin versions and read the migration guides.** Both frameworks have had breaking majors.

## Best Practices
- Write a custom data provider against your API rather than exposing a DB-direct provider with privileged keys in the browser.
- Normalize API errors in the provider (`{ message, statusCode, errors }`) so framework notifications and form field errors work.
- Map `accessControlProvider.can` (refine) or `canAccess`/permissions (react-admin) to a server-issued permission list. The server re-checks every request anyway.
- Keep URL sync on (refine `syncWithLocation`; react-admin list params live in the URL by default) so filtered lists are shareable. Check current docs for option names.
- Use the frameworks' `meta` or resource options for labels and icons instead of hard-coding nav.
- Generate list columns from a typed column config and share it between list and export.
- For big tables, keep pagination server-side. Don't set page size to "all".

## Implementation Guidance

### Decision table
| Criterion | refine (@refinedev/core 5.x) | react-admin (5.x) | Hand-rolled App Router |
|---|---|---|---|
| UI | Headless; integrations for Ant Design, MUI, Chakra, Mantine; or shadcn/Tailwind | Material UI (`ra-ui-materialui`) | Anything |
| Next.js | `@refinedev/nextjs-router`; `<Refine>` is a client component; server-side `authProviderServer.check()` in RSC | Client-only mount (`dynamic(..., { ssr: false })`) plus API proxy route | Native RSC + Server Actions |
| Data layer | TanStack Query v5 under the hood | TanStack Query v5 under the hood | RSC fetch / DAL, TanStack Query optional |
| Access control | `accessControlProvider.can({ resource, action, params })` → `useCan`, `<CanAccess>` | `authProvider.canAccess` / permissions, `<CanAccess>`-style components (check current docs) | Your own DAL + UI helpers |
| License | MIT core (commercial offerings exist; check current) | MIT; paid Enterprise Edition modules | n/a |

### refine data provider contract (shape)
`getList({ resource, pagination, sorters, filters, meta })` returns `{ data, total }`. Also `getOne`, `create`, `update`, `deleteOne`, `getApiUrl`, and optionally `getMany`, `custom`.
- `sorters`: `{ field: string; order: 'asc' | 'desc' }[]`
- `filters`: `{ field, operator, value }[]` (logical `or`/`and` groups are also possible)
- `pagination`: page size plus current page. The v5 property name may be `currentPage` rather than `current`; check current docs.

### react-admin data provider contract (shape)
`getList(resource, { pagination: { page, perPage }, sort: { field, order }, filter, meta })` returns `{ data, total }`. Also `getOne`, `getMany`, `getManyReference`, `create`, `update`, `updateMany`, `delete`, `deleteMany`. `updateMany`/`deleteMany` back the built-in bulk actions.

## Recommended Workflow
1. Inventory resources and API endpoints; confirm the API supports server-side pagination, sort and filter with a total count.
2. Choose the framework with the decision table. Prototype one resource end to end.
3. Implement the data provider: map params to query strings, map errors, attach auth via cookies (preferred) or a BFF proxy.
4. Implement the auth provider (login/logout/check/getIdentity/getPermissions) against your auth backend.
5. Implement access control from server-issued permissions; hide or disable UI accordingly.
6. Register resources and generate list/show/edit/create screens. Customize columns, filters and forms.
7. Next.js: mount correctly (below), add server-side checks in layouts, and proxy API calls through Route Handlers if secrets are involved.
8. Test the provider mapping (unit), flows (Playwright) and API authorization (backend tests).

## Patterns

### refine in Next.js App Router
```tsx
// app/(admin)/refine-provider.tsx
'use client';
import { Refine } from '@refinedev/core';
import routerProvider from '@refinedev/nextjs-router';
import { dataProvider } from '@/lib/refine/data-provider';        // client-safe: calls /api/* with cookies
import { authProvider } from '@/lib/refine/auth-provider.client';
import { accessControlProvider } from '@/lib/refine/access-control';

export function RefineProvider({ children }: { children: React.ReactNode }) {
  return (
    <Refine
      routerProvider={routerProvider}
      dataProvider={dataProvider}
      authProvider={authProvider}
      accessControlProvider={accessControlProvider}
      resources={[
        { name: 'invoices', list: '/invoices', show: '/invoices/show/:id', edit: '/invoices/edit/:id', create: '/invoices/create' },
      ]}
      options={{ syncWithLocation: true }}
    >
      {children}
    </Refine>
  );
}
```
```tsx
// app/(admin)/layout.tsx  (Server Component)
import { redirect } from 'next/navigation';
import { authProviderServer } from '@/lib/refine/auth-provider.server';
import { RefineProvider } from './refine-provider';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { authenticated } = await authProviderServer.check();
  if (!authenticated) redirect('/login');
  return <RefineProvider>{children}</RefineProvider>;
}
```
Keep separate server and client auth providers. Functions can't be passed from Server to Client Components.

### refine access control (UX gate)
```tsx
'use client';
import { CanAccess } from '@refinedev/core';
export function VoidButton({ id }: { id: string }) {
  return (
    <CanAccess resource="invoices" action="void" params={{ id }} fallback={null}>
      <button type="button">Void</button>
    </CanAccess>
  );
}
```

### react-admin mounted client-only in Next.js
```tsx
// app/admin/admin-app.tsx
'use client';
import { Admin, Resource, ListGuesser, EditGuesser } from 'react-admin';
import simpleRestProvider from 'ra-data-simple-rest';
const dataProvider = simpleRestProvider('/api/admin'); // same-origin proxy; no secrets in browser
export default function AdminApp() {
  return (
    <Admin dataProvider={dataProvider}>
      <Resource name="invoices" list={ListGuesser} edit={EditGuesser} />
    </Admin>
  );
}
```
```tsx
// app/admin/admin-loader.tsx
'use client';
import dynamic from 'next/dynamic';
const AdminApp = dynamic(() => import('./admin-app'), { ssr: false });
export function AdminLoader() { return <AdminApp />; }
```
```tsx
// app/admin/page.tsx
import { AdminLoader } from './admin-loader';
export default function Page() { return <AdminLoader />; }
```
```ts
// app/api/admin/[...slug]/route.ts — BFF proxy: authenticates, authorizes, injects server-side credentials
import { getSession } from '@/data/auth';
export async function GET(req: Request, { params }: { params: Promise<{ slug: string[] }> }) {
  const session = await getSession();
  if (!session) return new Response('Unauthorized', { status: 401 });
  const { slug } = await params;
  const url = new URL(req.url);
  const upstream = `${process.env.ADMIN_API_URL}/${slug.map(encodeURIComponent).join('/')}${url.search}`;
  const res = await fetch(upstream, { headers: { Authorization: `Bearer ${await session.getUpstreamToken()}` } });
  return new Response(res.body, { status: res.status, headers: { 'Content-Type': res.headers.get('Content-Type') ?? 'application/json', 'Content-Range': res.headers.get('Content-Range') ?? '' } });
}
```
The simple REST provider relies on a total-count header such as `Content-Range`; check the provider docs for the exact header and CORS exposure rules. Add POST/PUT/DELETE handlers with the same checks, and allowlist the upstream paths.

## Anti-Patterns
- **Service-role or admin DB keys in a browser data provider.** Anyone can read them from the bundle. Fix: a same-origin proxy or backend with per-user auth.
- **Trusting `accessControlProvider` or `<CanAccess>` as enforcement.** Fix: enforce in the API or Route Handler; UI gates are cosmetic.
- **Rendering react-admin during SSR in Next.js.** Causes router/emotion errors. Fix: `dynamic(..., { ssr: false })` inside a client component.
- **Passing provider functions from a Server Component into `<Refine>`.** Serialization error. Fix: define providers in `'use client'` modules.
- **Client-side filtering because the API lacks filters.** Fix: add server filters or use a different screen type.
- **Guesser components in production.** Fix: replace `ListGuesser`/`EditGuesser` with explicit columns and inputs.
- **Mixing framework URL state with a separate nuqs state for the same list.** Two sources of truth. Fix: pick one.

## Accessibility
- Material UI (react-admin) and refine UI integrations inherit their base library's accessibility; audit custom columns, icon-only buttons (`aria-label`) and filter popovers.
- Make sure notifications (toasts) are announced (live region) and don't auto-dismiss critical errors (WCAG 2.2.1).
- Verify focus after save/delete redirects lands on a heading or the updated row.
- Datagrid row click navigation must also be reachable by keyboard (a link in the first cell).

## Responsive Design
- react-admin ships responsive layouts (e.g., `SimpleList` for small screens); switch list components by breakpoint.
- refine is headless, so responsiveness comes from the chosen UI kit or your own components. Provide a card/list fallback for narrow viewports.

## Performance
- Both use TanStack Query: tune `staleTime` per resource and avoid refetch storms on window focus for heavy lists.
- react-admin is a large client bundle. Keep it on its own route segment so marketing and app pages don't load it.
- For refine in Next.js, keep the `<Refine>` provider scoped to the admin route group.
- Use `getMany` batching for reference fields to avoid N+1 requests.

## Security
- The API must enforce authentication, authorization, tenant scoping and field-level visibility, whatever the providers do.
- Prefer httpOnly cookies over tokens in localStorage (see [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md)).
- The proxy route must allowlist upstream paths and methods to avoid SSRF or open-proxy behavior, and must not forward client-supplied auth headers blindly.
- Bulk `updateMany`/`deleteMany` endpoints need the same per-record checks as single-record endpoints.
- Never put secrets in `NEXT_PUBLIC_*` variables.

## Testing
- Unit test data provider mapping: pagination, sort and filter to query string, and error normalization.
- MSW (see [api-mocking-msw](../api-mocking-msw/Skill.md)) to run list/edit flows in component tests.
- Playwright: login, list filter persisted in URL, edit, and a permission-hidden action.
- Backend tests prove that forbidden actions return 403 even when called directly.

## Tooling
- `@refinedev/core` 5.0.12 (Apr 2026), `@refinedev/nextjs-router`, UI integrations (Ant Design, MUI, Chakra, Mantine).
- `react-admin` 5.15.3 (MIT; peer React 18/19; MUI 5–9 range; react-router 6/7; TanStack Query v5), `ra-data-simple-rest` and 45+ community data providers, Enterprise Edition (paid).
- Alternatives: hand-rolled App Router + TanStack Table, or UI5 Web Components for React (Fiori look).

## Framework Notes
- **Next.js:** refine supports the App Router via `@refinedev/nextjs-router`; some helpers (e.g., `UnsavedChangesNotifier`, `DocumentTitleHandler`) were documented as `/pages`-only, so check current docs. react-admin is mounted client-only; use Route Handlers as a BFF.
- **React (Vite SPA):** the native home for react-admin, and refine works with its React Router integration. All enforcement lives in the backend API.

## AI Agent Guidance
- Do:
  - Confirm the framework version in `package.json` before writing code; provider shapes changed between majors.
  - Write a custom provider against the real API.
  - Mount react-admin client-only.
  - Keep `<Refine>` in a client module.
- Don't:
  - Put DB or service keys in providers.
  - Treat `can`/`CanAccess` as security.
  - Leave Guesser components in the final code.
- Verify before done:
  - Server-side pagination works (network shows page params).
  - Reload keeps filters.
  - Forbidden API calls return 403.
  - No secrets are in the client bundle (search the build output for env values).

## Examples

### refine data provider (fetch-based, cookie auth)
```ts
'use client';
import type { DataProvider } from '@refinedev/core';

const API = '/api';
const toQuery = (p: Parameters<DataProvider['getList']>[0]) => {
  const q = new URLSearchParams();
  const pg = p.pagination as { currentPage?: number; current?: number; pageSize?: number } | undefined;
  q.set('page', String(pg?.currentPage ?? pg?.current ?? 1)); // name differs across versions — check docs
  q.set('pageSize', String(pg?.pageSize ?? 25));
  p.sorters?.forEach((s) => q.append('sort', `${s.field}.${s.order}`));
  p.filters?.forEach((f) => { if ('field' in f) q.append(`filter[${f.field}][${f.operator}]`, String(f.value)); });
  return q;
};

export const dataProvider: DataProvider = {
  getApiUrl: () => API,
  getList: async (params) => {
    const res = await fetch(`${API}/${params.resource}?${toQuery(params)}`, { credentials: 'include' });
    if (!res.ok) throw { message: 'Failed to load', statusCode: res.status };
    const body = (await res.json()) as { rows: any[]; total: number };
    return { data: body.rows, total: body.total };
  },
  getOne: async ({ resource, id }) => ({ data: await (await fetch(`${API}/${resource}/${id}`, { credentials: 'include' })).json() }),
  create: async ({ resource, variables }) => ({ data: await (await fetch(`${API}/${resource}`, { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(variables) })).json() }),
  update: async ({ resource, id, variables }) => ({ data: await (await fetch(`${API}/${resource}/${id}`, { method: 'PATCH', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(variables) })).json() }),
  deleteOne: async ({ resource, id }) => ({ data: await (await fetch(`${API}/${resource}/${id}`, { method: 'DELETE', credentials: 'include' })).json() }),
};
```
Add `res.ok` checks and error normalization to every method in real code.

## Related Skills
- [admin-panel-architecture](../admin-panel-architecture/Skill.md) — hand-rolled alternative and shared principles
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — what access control providers should map to
- [enterprise-data-tables](../enterprise-data-tables/Skill.md) — list screen UX
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — underlying cache layer
- [material-ui](../material-ui/Skill.md) — react-admin's UI base
- [ant-design](../ant-design/Skill.md) — common refine UI integration
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — BFF proxy
- [vite-react-spa](../vite-react-spa/Skill.md) — SPA hosting option

## Sources
- [refine general concepts](https://refine.dev/docs/guides-concepts/general-concepts/) — Official — providers, getList params, accessControlProvider, hooks, UI integrations
- [refine Next.js router integration](https://refine.dev/docs/routing/integrations/next-js/) — Official — client `<Refine>`, `authProviderServer`, limitations, folder structure
- [refine releases](https://github.com/refinedev/refine/releases) — Open Source — @refinedev/core 5.0.12 (Apr 2026)
- [react-admin README](https://github.com/marmelab/react-admin) — Open Source — features, data providers, MIT + Enterprise Edition
- [react-admin Next.js guide](https://github.com/marmelab/react-admin/blob/master/docs/NextJs.md) — Official — client-only dynamic import, catch-all API proxy
- [react-admin on npm](https://www.npmjs.com/package/react-admin) — Official — v5.15.3, dependency ranges
- [Next.js data security](https://nextjs.org/docs/app/guides/data-security) — Official — server-side enforcement principles

## License / Usage Notes
refine core and react-admin are MIT (both vendors sell commercial add-ons or support; check current terms). This file summarizes their documentation; code is original.

## Quality Tier
A — versions, Next.js integration and provider concepts verified against official docs and registries; some exact v5 prop names are flagged "check current docs".

## Status
Active

## Last Verified
2026-09-15
