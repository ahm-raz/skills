# Multi-Tenant UI

## Summary
Patterns for B2B SaaS and enterprise apps where one user can belong to several organizations, workspaces or tenants: tenant resolution (path, subdomain, custom domain), the org switcher, tenant-scoped data access in Next.js, per-tenant branding and settings, cache isolation, and the "wrong-tenant" failure modes that cause data leaks.

## Category
Enterprise UI

## Subcategories
Tenant resolution, organization switcher, workspace scoping, tenant branding, cache isolation, invitations, cross-tenant admin (support/impersonation)

## Problem It Solves
Multi-tenant bugs are both severe and subtle. Examples: a cached page served to another org, a Server Action that trusts a `tenantId` form field, a client store that keeps org A's data after switching to org B, a CSV export missing the tenant filter. Users also lose context when the active org isn't obvious. This skill makes tenant context explicit, server-verified and visible.

## When To Use
- Users can belong to more than one org or workspace, or staff must view customers' tenants.
- Per-tenant subdomains or custom domains, per-tenant theming or feature entitlements.
- Any app where data rows carry a `tenant_id`/`org_id`.

## When Not To Use
- Single-tenant internal tools with one global dataset.
- Consumer apps with purely personal data. Per-user ownership checks suffice there (still enforce them).

## Core Principles
1. **Derive the tenant on the server from a trusted source** (session membership + route/host), never from a client-supplied body field.
2. **Every query is tenant-scoped in the DAL**, ideally backed by database row-level security as defense in depth.
3. **Tenant context is always visible.** The org name/logo sits in the top bar, and destructive dialogs name the org.
4. **Switching tenants resets all tenant-bound client state** (query caches, stores, selection, drafts).
5. **Caches are keyed by tenant.** Shared caches never mix tenants.
6. **Membership is re-checked per request.** Access removed in org A takes effect immediately.

## Best Practices
- **Resolution strategy:**
  - Path-based `/{orgSlug}/...` is simplest, works on one domain and makes links self-describing. Prefer it by default.
  - Subdomains (`acme.app.com`) give stronger visual identity but need wildcard DNS/TLS and cookie domain decisions.
  - Custom domains need domain verification and a host→tenant lookup in `proxy.ts`.
- Put the org switcher top-left (it frames everything below) or in the user menu for rarely-switched setups. Show the current org, a searchable list (combobox for >7 orgs), a role badge per org, "Create organization" and "Pending invitations".
- Remember the last active org per user (cookie or DB) for the post-login redirect, but always validate membership.
- Deep links to another org's record: if the user is a member, switch with a notice ("Switched to Globex"). If not, show a 404 (don't reveal existence).
- Branding: per-tenant logo and accent color via CSS variables on a wrapper. Validate colors for contrast and never inject raw CSS from tenant input.
- Entitlements (plan features) differ from permissions (role). Model both, and show upgrade prompts for entitlement gaps, not "access denied".
- Support staff or impersonation: use a persistent, high-contrast banner ("Viewing as support in Acme — read-only"), time-boxed sessions, a reason prompt and audit entries.

## Implementation Guidance

### Tenant-scoped routing (path-based)
```
app/
  (marketing)/page.tsx
  select-org/page.tsx
  [org]/
    layout.tsx          // resolves org + membership (UX), renders switcher
    page.tsx
    invoices/page.tsx
    settings/members/page.tsx
data/
  tenant.ts             // getTenantContext(orgSlug): session + membership (server-only, cached per request)
```

### Tenant context in the DAL
```ts
// data/tenant.ts
import 'server-only';
import { cache } from 'react';
import { notFound } from 'next/navigation';
import { getSession } from './auth';
import { db } from './db';

export type TenantContext = { userId: string; orgId: string; orgSlug: string; role: 'owner' | 'admin' | 'member' | 'viewer' };

export const getTenantContext = cache(async (orgSlug: string): Promise<TenantContext> => {
  const session = await getSession();
  if (!session) throw new Error('Unauthorized');
  const m = await db.membership.findFirst({
    where: { user: { id: session.userId }, org: { slug: orgSlug }, revokedAt: null },
    select: { role: true, org: { select: { id: true, slug: true } } },
  });
  if (!m) notFound(); // don't disclose that the org exists
  return { userId: session.userId, orgId: m.org.id, orgSlug: m.org.slug, role: m.role };
});
```
```ts
// data/invoices.ts
import 'server-only';
import { getTenantContext } from './tenant';
export async function listInvoices(orgSlug: string, query: { page: number; pageSize: number }) {
  const t = await getTenantContext(orgSlug);
  return db.invoice.findMany({
    where: { orgId: t.orgId }, // ALWAYS from context, never from input
    select: { id: true, number: true, total: true, status: true },
    skip: (query.page - 1) * query.pageSize, take: query.pageSize,
  });
}
```

### Decision table: where does the tenant come from?
| Source | Trust | Use |
|---|---|---|
| Route `[org]` slug / host | Untrusted input → must be verified against membership | Selecting which membership to use |
| Session membership (DB lookup) | Trusted | Authorization and scoping |
| Hidden form field `orgId` | Untrusted | Never for scoping; at most cross-check equality |
| Client store / localStorage | Untrusted | UX preference only (last org) |

## Recommended Workflow
1. Choose the resolution strategy (path/subdomain/custom domain) and the cookie domain.
2. Model `Organization`, `Membership(role)`, `Invitation`, and entitlements per plan.
3. Build `getTenantContext` and require it in every DAL function. Add DB row-level security if available.
4. Build the `[org]` layout with the switcher, and the `select-org` page for users with zero or several orgs.
5. Wire switching: navigate to `/{newOrg}/...` and clear client caches.
6. Scope caches and revalidation tags by org.
7. Add invitation, member management and leave-org flows.
8. Write cross-tenant tests for every resource, export and action.

## Patterns

### Org switcher (client) with cache reset
```tsx
'use client';
import { useRouter } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';

type Org = { slug: string; name: string; role: string };
export function OrgSwitcher({ current, orgs }: { current: Org; orgs: Org[] }) {
  const router = useRouter();
  const qc = useQueryClient();
  return (
    <label className="org-switcher">
      <span className="sr-only">Organization</span>
      <select
        value={current.slug}
        onChange={(e) => {
          qc.clear();                      // drop tenant-bound client cache
          router.push(`/${e.target.value}`); // go to new org home, not same deep path (record may not exist)
        }}
      >
        {orgs.map((o) => <option key={o.slug} value={o.slug}>{o.name} — {o.role}</option>)}
      </select>
    </label>
  );
}
```
For large org lists, use an accessible combobox (see [select-and-combobox](../select-and-combobox/Skill.md)).

### Tenant-scoped cache tags
```ts
// data/invoices.ts (Next.js caching)
import { unstable_cacheTag as cacheTag } from 'next/cache'; // API names vary by Next.js version — check current docs
export async function getInvoiceStats(orgId: string) {
  'use cache';
  cacheTag(`org:${orgId}:invoices`);
  return db.invoice.aggregate({ where: { orgId }, _sum: { total: true } });
}
// after mutation: revalidateTag(`org:${orgId}:invoices`)
```
Only cache tenant data when the cache key includes the tenant. Never cache per-user permission results in a shared cache without the user in the key.

### Tenant branding via CSS variables
```tsx
export function TenantTheme({ accent, children }: { accent: string; children: React.ReactNode }) {
  const safe = /^#[0-9a-f]{6}$/i.test(accent) ? accent : '#2563eb'; // validate; contrast-check at save time
  return <div style={{ ['--tenant-accent' as string]: safe }}>{children}</div>;
}
```

## Anti-Patterns
- **`where: { orgId: formData.get('orgId') }`.** An attacker changes the field and reads or writes another tenant. Fix: derive the org from `getTenantContext`.
- **Checking membership only in `[org]/layout.tsx`.** Actions and Route Handlers bypass layouts. Fix: check in the DAL.
- **Keeping the TanStack Query cache or Zustand store across an org switch.** Flashes or leaks previous-org data. Fix: clear or reset on switch, and key queries by org.
- **Unkeyed shared caches** (`'use cache'` or CDN) for tenant pages. Fix: include the tenant in the key/tags, or mark the page dynamic.
- **A 403 page that says "Acme Corp: access denied".** Discloses tenant existence. Fix: 404 for non-members.
- **Tenant-supplied raw CSS or HTML for branding.** XSS and UI spoofing. Fix: constrained tokens (logo URL from your storage, validated colors).
- **Invisible impersonation.** Fix: a persistent banner, read-only by default, audited.

## Accessibility
- The org switcher needs a visible label or `aria-label`, and must be a proper combobox/listbox with type-ahead.
- When the org changes, announce it ("Switched to Globex") via a live region and move focus to the main heading.
- Tenant accent colors must still meet contrast (WCAG 1.4.3 text, 1.4.11 non-text). Enforce at save time with a fallback.
- The impersonation banner must be reachable and readable by screen readers (`role="status"` or a landmark region with a label).

## Responsive Design
- On mobile, move the switcher into the navigation drawer header; keep the current org name visible in the app bar (truncate with a tooltip or full name in the drawer).
- The org list becomes a full-screen sheet on small viewports.

## Performance
- `getTenantContext` is wrapped in React `cache()`, so membership is fetched once per request.
- Index `(org_id, ...)` on every tenant table; composite indexes match list sort orders.
- Prefetch the org home on switcher hover or focus for fast switching.
- Keep per-tenant branding in CSS variables (no theme recompute or re-bundle).

## Security
- Scope every read, write, export, search index, file URL and websocket room by tenant. Signed URLs and realtime rooms must embed a tenant-verified path.
- Use database row-level security or a scoped query builder as a second layer.
- Cookie scope for subdomains: decide deliberately between a host-only and a parent-domain cookie. Parent-domain cookies are shared across all tenant subdomains.
- Custom domains: verify ownership (DNS TXT) before routing, and prevent host header spoofing by resolving only verified domains.
- Record `orgId`, actor and impersonator in audit logs.
- Invitations: single-use, expiring tokens bound to the email. Show the org name before acceptance.

## Testing
- A cross-tenant matrix: user in org A requests org B's list, detail, update action, export and file download, expecting 404/403 for each.
- Revoked membership takes effect on the next request (no stale session role).
- Org switch E2E: no previous-org rows visible after switching (assert on a unique marker).
- Cache tests: a page rendered for org A is never served to org B (inspect cache keys/tags).

## Tooling
- Auth providers with organizations (Clerk Organizations, WorkOS, Auth0 Organizations, Better Auth org plugin; check current features).
- Postgres row-level security (Supabase, Neon) for defense in depth.
- OpenFGA or Permit.io for cross-tenant relationships (e.g., partner access).
- nuqs for tenant-local list state (the org lives in the path, not the query string).

## Framework Notes
- **Next.js:** a `[org]` dynamic segment plus `getTenantContext` in the DAL. `proxy.ts` can rewrite subdomain or custom-domain hosts to `/[org]` paths, but it must not be the only authorization. `params` is a Promise. Scope `revalidateTag`/`revalidatePath` per org.
- **React (Vite SPA):** the tenant comes from the router param. Send it as a path segment to the API, which re-verifies membership. Key TanStack Query caches with `['org', orgSlug, ...]` and call `queryClient.clear()` on switch.

## AI Agent Guidance
- Do:
  - Grep for every DB query and confirm it filters by the context-derived tenant.
  - Add a cross-tenant test per new resource.
  - Include the org in cache keys and query keys.
- Don't:
  - Accept `orgId` from forms, query strings or client stores for scoping.
  - Leave client caches intact on switch.
- Verify before done:
  - A forged `orgId` or slug returns 404.
  - Switching orgs shows no stale data.
  - Exports and file URLs are scoped.
  - The impersonation banner renders.

## Examples

### Server Action with tenant scope and ownership
```ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { getTenantContext } from '@/data/tenant';
import { db } from '@/data/db';

const Input = z.object({ org: z.string().min(1), id: z.string().uuid() });
export async function archiveProject(formData: FormData) {
  const { org, id } = Input.parse(Object.fromEntries(formData));
  const t = await getTenantContext(org);                  // membership verified
  if (!['owner', 'admin'].includes(t.role)) throw new Error('Forbidden');
  const res = await db.project.updateMany({ where: { id, orgId: t.orgId }, data: { archivedAt: new Date() } });
  if (res.count === 0) throw new Error('Not found');      // wrong-tenant id looks like not found
  revalidatePath(`/${t.orgSlug}/projects`);
}
```

## Related Skills
- [admin-panel-architecture](../admin-panel-architecture/Skill.md) — DAL and resource structure this builds on
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — per-org roles and permission checks
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — tenant-scoped audit and impersonation logging
- [saas-application-patterns](../saas-application-patterns/Skill.md) — broader SaaS product patterns
- [nextjs-middleware-proxy](../nextjs-middleware-proxy/Skill.md) — host/subdomain rewrites
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — cache keying and tags
- [theming-with-css-variables](../theming-with-css-variables/Skill.md) — tenant branding
- [nextjs-authentication](../nextjs-authentication/Skill.md) — sessions and membership
- [select-and-combobox](../select-and-combobox/Skill.md) — org switcher control

## Sources
- [Next.js: How to think about data security](https://nextjs.org/docs/app/guides/data-security) — Official — DAL, IDOR/ownership checks, re-auth in actions, return-value filtering
- [OpenFGA: Perform a check](https://openfga.dev/docs/getting-started/perform-check) — Official — relationship checks usable for org/partner access
- [Permit.io docs](https://docs.permit.io/) — Official — multi-tenancy and RBAC/ABAC/ReBAC concepts
- [NN/g: Complex application design](https://www.nngroup.com/articles/complex-application-design/) — Community (research) — visible context, reducing clutter

## License / Usage Notes
Summarized guidance; code is original. Tenant-routing and caching practices are synthesized from the Next.js security guide and general SaaS practice. Next.js cache API names change between versions, so check current docs.

## Quality Tier
B — security core verified against official Next.js docs; switcher, branding and impersonation UX synthesized from established practice rather than a single authoritative source.

## Status
Active

## Last Verified
2026-09-15
