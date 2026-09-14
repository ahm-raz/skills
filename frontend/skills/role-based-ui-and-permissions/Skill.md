# Role-Based UI and Permissions

## Summary
How to model permissions (RBAC, ABAC, ReBAC) and reflect them in a React/Next.js UI (hide, disable or explain) while enforcing them where they matter: the Data Access Layer, Server Actions and Route Handlers. Covers a single shared policy definition, CASL for isomorphic ability checks, OpenFGA and Permit.io for externalized authorization, and UX rules for unavailable actions.

## Category
Enterprise UI

## Subcategories
RBAC, ABAC, ReBAC, CASL, OpenFGA, Permit.io, permission-aware navigation, field-level permissions, disabled vs hidden actions

## Problem It Solves
Teams sprinkle `user.role === 'admin'` across components. The UI and server drift apart, buttons show that fail with 403, forbidden actions still work via direct POST, and adding a role means editing 80 files. A single policy, evaluated on the server and projected to the client, keeps UX and enforcement consistent.

## When To Use
- More than two roles, per-resource ownership rules, per-org roles, or field-level visibility.
- Admin panels, B2B SaaS, approval workflows, anything with "who can do what" requirements.

## When Not To Use
- Single-role apps (logged-in = full access). A session check in the DAL is enough.
- As a replacement for server enforcement. This skill never replaces it.

## Core Principles
1. **The UI is never the security boundary.** Every mutation and every sensitive read is authorized on the server (DAL / Server Action / Route Handler). Server Actions are reachable by direct POST.
2. **One policy source.** Define abilities once and evaluate the same rules on the server and, when useful, the client.
3. **Check permissions, not roles, in UI code.** `can('void', invoice)` instead of `role === 'finance'`. Roles map to permissions in one place.
4. **Least privilege and default deny.** Unknown actions are forbidden.
5. **Contextual checks need the resource.** Ownership, status ("can edit only drafts") and tenant are inputs, not afterthoughts.
6. **Explain, don't just hide.** Hide what a user will never have. Disable (with a reason) what they could get or what depends on state.

## Best Practices
- **Pick the model:**
  - **RBAC:** roles → permission sets. Simple; covers most admin panels.
  - **ABAC:** rules on attributes (`invoice.status === 'draft' && invoice.amount < 10k`). Needed for state-dependent actions.
  - **ReBAC:** relationships (user is `editor` of `folder` which is `parent` of `doc`). Needed for sharing, hierarchies and partner access. Use OpenFGA (Zanzibar-style) or Permit.io.
- Name permissions as `resource:action` (`invoice:void`, `member:invite`). Keep a matrix doc (role × permission) that product owns.
- **UI rules:**
  - **Navigation:** hide sections the user can't read.
  - **Record actions:** if the user lacks permission regardless of state, hide it. If it's state-dependent ("only drafts can be edited"), show it disabled with a tooltip or inline reason.
  - **Page access:** a server-side `notFound()` (don't disclose existence) or a friendly "You don't have access — request access from {owner}" when the resource's existence is already known to the user.
  - **Fields:** omit forbidden fields from DTOs server-side. Read-only fields render as text, not disabled inputs.
- Offer "Request access" flows in B2B apps. They cut support tickets.
- Ship the client a **serialized, minimal permission set** (CASL rules or a permission list) from the server. Recompute on role change and after org switch.
- Preview-as-role (for admins configuring roles) is valuable, but it must be read-only and audited.

## Implementation Guidance

### Layers
| Layer | Responsibility | Tool |
|---|---|---|
| Policy definition | Roles → rules, conditions | CASL `defineAbilityFor`, OpenFGA model, Permit policies |
| Enforcement (must) | DAL functions, Server Actions, Route Handlers, DB RLS | `ability.can` / `ForbiddenError`, `fga.check`, `permit.check` |
| Data shaping (must) | DTOs omit forbidden fields; lists filtered to accessible rows | CASL `accessibleBy` (with ORM adapters; check docs), OpenFGA `listObjects` |
| UI projection (UX) | Hide or disable actions, nav, fields | `@casl/react` `<Can>`, `useAbility`, precomputed booleans from RSC |

### Decision table: where to compute UI permissions in Next.js
| Situation | Approach |
|---|---|
| Server-rendered page, few actions | Compute booleans in the RSC (`canVoid`) and pass them as props; no client policy code |
| Rich client UI (tables with per-row actions, editors) | Serialize CASL rules to the client, `createMongoAbility(rules)` in a provider, `<Can>` per row |
| ReBAC (sharing, hierarchies) | Server `batchCheck` or `listObjects` per page of rows; pass per-row flags |
| Vite SPA | `GET /me/permissions` returns rules; the API enforces |

## Recommended Workflow
1. Write the permission matrix (roles × `resource:action`, with conditions).
2. Choose the engine: CASL for in-app RBAC/ABAC; OpenFGA or Permit.io when relationships, externalized policy or cross-service reuse matter.
3. Implement `defineAbilityFor(user, tenant)` in a shared module with no server imports, so it can be used on both sides.
4. Enforce in the DAL. Every function calls `authorize(action, subject)` before touching data, and list queries filter to accessible rows.
5. Project to the UI: RSC booleans or a client `AbilityProvider` seeded with serialized rules.
6. Implement unavailable-action UX (hidden, disabled + reason, request access).
7. Test: unit-test the policy per role; integration-test actions with forbidden roles via direct calls; E2E-test visibility.

## Patterns

### Shared CASL ability (isomorphic)
```ts
// lib/authz/ability.ts  (no server-only imports; safe for client)
import { AbilityBuilder, createMongoAbility, type MongoAbility } from '@casl/ability';

export type Actions = 'read' | 'create' | 'update' | 'delete' | 'void' | 'approve' | 'export';
export type Subjects = 'Invoice' | 'Member' | 'Report' | 'all';
export type AppAbility = MongoAbility<[Actions, Subjects]>;
export type Viewer = { id: string; orgRole: 'owner' | 'admin' | 'finance' | 'viewer' };

export function defineAbilityFor(v: Viewer) {
  const { can, cannot, build } = new AbilityBuilder<AppAbility>(createMongoAbility);
  can('read', 'Invoice');
  if (v.orgRole === 'finance' || v.orgRole === 'admin' || v.orgRole === 'owner') {
    can(['create', 'update'], 'Invoice', { status: 'draft' });
    can('void', 'Invoice', { status: { $in: ['open'] } });
    can('export', 'Invoice');
  }
  if (v.orgRole === 'owner' || v.orgRole === 'admin') can(['read', 'create', 'update', 'delete'], 'Member');
  cannot('delete', 'Member', { role: 'owner' });
  return build();
}
```
Checking conditions against plain objects requires CASL's `subject('Invoice', obj)` helper or a `detectSubjectType` config; check the CASL docs for the variant you use.

### Server enforcement in the DAL
```ts
// data/invoices.ts
import 'server-only';
import { subject } from '@casl/ability';
import { defineAbilityFor } from '@/lib/authz/ability';
import { getTenantContext } from './tenant';

export async function voidInvoice(orgSlug: string, id: string, reason: string) {
  const t = await getTenantContext(orgSlug);
  const ability = defineAbilityFor({ id: t.userId, orgRole: t.role as any });
  const inv = await db.invoice.findFirst({ where: { id, orgId: t.orgId }, select: { id: true, status: true } });
  if (!inv) throw new Error('Not found');
  if (!ability.can('void', subject('Invoice', inv))) throw new Error('Forbidden');
  await db.$transaction([
    db.invoice.update({ where: { id }, data: { status: 'void' } }),
    db.auditEvent.create({ data: { orgId: t.orgId, actorId: t.userId, action: 'invoice.void', targetId: id, metadata: { reason } } }),
  ]);
}
```

### Client projection with @casl/react
```tsx
// app/[org]/ability-provider.tsx
'use client';
import { createContext, useMemo } from 'react';
import { createContextualCan } from '@casl/react';
import { createMongoAbility, type RawRuleOf } from '@casl/ability';
import type { AppAbility } from '@/lib/authz/ability';

export const AbilityContext = createContext<AppAbility>(createMongoAbility());
export const Can = createContextualCan(AbilityContext.Consumer);

export function AbilityProvider({ rules, children }: { rules: RawRuleOf<AppAbility>[]; children: React.ReactNode }) {
  const ability = useMemo(() => createMongoAbility<AppAbility>(rules), [rules]);
  return <AbilityContext.Provider value={ability}>{children}</AbilityContext.Provider>;
}
```
```tsx
// app/[org]/layout.tsx (Server Component) — serialize rules, not the user object
const t = await getTenantContext(org);
const rules = defineAbilityFor({ id: t.userId, orgRole: t.role }).rules;
return <AbilityProvider rules={rules}>{children}</AbilityProvider>;
```

### Hidden vs disabled-with-reason
```tsx
'use client';
import { useContext } from 'react';
import { subject } from '@casl/ability';
import { AbilityContext } from './ability-provider';

export function InvoiceActions({ invoice }: { invoice: { id: string; status: 'draft' | 'open' | 'paid' | 'void' } }) {
  const ability = useContext(AbilityContext);
  const inv = subject('Invoice', invoice);
  const hasRolePermission = ability.can('void', 'Invoice');   // type-level: role has it at all?
  if (!hasRolePermission) return null;                          // hide: never available
  const allowedNow = ability.can('void', inv);                  // condition-level: state allows?
  return (
    <button type="button" aria-disabled={!allowedNow} aria-describedby={!allowedNow ? `void-why-${invoice.id}` : undefined}
      onClick={() => { if (allowedNow) {/* open confirm dialog */} }}>
      Void
      {!allowedNow && <span id={`void-why-${invoice.id}`} className="sr-only"> — only open invoices can be voided</span>}
    </button>
  );
}
```

### ReBAC with OpenFGA (server)
```ts
import 'server-only';
import { OpenFgaClient } from '@openfga/sdk';
const fga = new OpenFgaClient({ apiUrl: process.env.FGA_API_URL!, storeId: process.env.FGA_STORE_ID!, authorizationModelId: process.env.FGA_MODEL_ID });

export async function canEditDoc(userId: string, docId: string) {
  const { allowed } = await fga.check({ user: `user:${userId}`, relation: 'editor', object: `document:${docId}` });
  return allowed === true;
}
// For a table page: batchCheck the visible row ids (SDK splits batches), or listObjects to fetch accessible ids first.
```

## Anti-Patterns
- **Only `<Can>` around the button.** A direct POST to the action still works. Fix: authorize in the DAL/action, and add a test that calls the action as a forbidden role.
- **`role === 'admin'` checks scattered in components.** Fix: permission checks against a central ability.
- **Sending the full user record or all tenant roles to the client for checks.** Fix: send serialized rules or booleans only.
- **Disabled buttons with no explanation.** Users think the app is broken. Fix: inline reason or tooltip, reachable by keyboard and screen readers.
- **Showing actions and letting the server 403.** Frustrating. Fix: project permissions so the UI matches.
- **Filtering forbidden rows client-side.** Leaks data in the payload. Fix: filter in the query.
- **Caching permission results across users or tenants.** Fix: key by user + tenant, with a short TTL, invalidated on role change.
- **Disabled form inputs for read-only data.** Poor contrast and not focusable. Fix: render as text or `readOnly`.

## Accessibility
- Prefer `aria-disabled="true"` (focusable, can expose a reason) over `disabled` when a reason must be discoverable. Block activation in the handler.
- Tooltips on disabled controls: native `disabled` elements don't receive focus or hover reliably, so use `aria-disabled` plus `aria-describedby` for the reason (WCAG 1.3.1, 4.1.2).
- "Access denied" pages need a clear heading, the reason, and a next step (request access, switch org).
- Don't rely on greyed-out color alone for unavailable state (WCAG 1.4.1).

## Responsive Design
- Overflow menus on mobile should also omit hidden actions and show disabled ones with the reason as secondary text, since tooltips don't work on touch.
- Permission-driven nav changes must not leave empty groups or dividers.

## Performance
- Build the ability once per request (`cache()`) on the server, and memoize it on the client from serialized rules.
- For ReBAC tables, batch checks per page instead of per-row network calls, or use `listObjects` to pre-filter.
- Keep serialized rules small; don't ship rules for unrelated modules.

## Security
- Enforcement points: DAL (reads + writes), Server Actions, Route Handlers, background jobs, exports, file downloads, websockets/realtime auth endpoints.
- Validate the subject from the DB, not from client-sent attributes. A client could send `status: 'draft'` to pass a condition.
- Default deny for unknown actions, and handle policy-engine outages safely (fail closed).
- Log authorization denials (rate-limited) and privileged grants and role changes in the audit log.
- Role changes take effect immediately: re-read membership per request or invalidate sessions.
- Keep secrets for OpenFGA/Permit in server env only.

## Testing
- Policy unit tests: table-driven (role, action, subject state) → expected boolean.
- Action tests: call each Server Action or DAL function as every role, including cross-tenant, and expect `Forbidden`/`Not found`.
- E2E (Playwright): log in per role (storage state per role) and assert the visibility and disabled reasons of key actions.
- Snapshot the permission matrix and fail CI when it changes without a reviewed update.

## Tooling
- **CASL** (`@casl/ability`, `@casl/react`, MIT): isomorphic RBAC/ABAC; `<Can I/do on/a/this field not passThrough>`, `createContextualCan`, `useAbility`, render-function children.
- **OpenFGA** (`@openfga/sdk`, Apache-2.0, CNCF): ReBAC, `check`, `batchCheck`, `listObjects`.
- **Permit.io** (commercial SaaS with a local PDP): RBAC/ABAC/ReBAC, `permit.check(user, action, resource)`, frontend integration with CASL, embeddable user management. Check current pricing and licensing.
- Also consider Cerbos, Oso or Postgres RLS (check current status).

## Framework Notes
- **Next.js:** compute abilities in Server Components and the DAL, pass booleans or rules to client islands, enforce in every `'use server'` function and `route.ts`. `proxy.ts` may do coarse gating (logged-in or not) but not resource authorization. Mark policy-engine clients `server-only`.
- **React (Vite SPA):** fetch rules from the API after login and on org switch, and provide them via context. The API enforces with the same policy (share the CASL module in a monorepo package if the backend is Node).

## AI Agent Guidance
- Do:
  - Locate every mutation path (actions, route handlers, jobs) and add an authorization call before data access.
  - Use permission names, not role names, in UI code.
  - Load subjects from the DB before condition checks.
  - Add forbidden-role tests.
- Don't:
  - Consider the task done after adding `<Can>` wrappers.
  - Trust client-sent attributes for conditions.
  - Serialize user or session objects to the client.
- Verify before done:
  - Each action rejects a forbidden role when invoked directly.
  - Lists exclude inaccessible rows in the network payload.
  - Disabled actions announce their reason.

## Examples

### RSC-computed booleans (no client policy code)
```tsx
// app/[org]/invoices/[id]/page.tsx
import { subject } from '@casl/ability';
import { defineAbilityFor } from '@/lib/authz/ability';
import { getTenantContext } from '@/data/tenant';
import { getInvoiceDTO } from '@/data/invoices';
import { InvoiceHeader } from './invoice-header';

export default async function Page({ params }: { params: Promise<{ org: string; id: string }> }) {
  const { org, id } = await params;
  const t = await getTenantContext(org);
  const invoice = await getInvoiceDTO(org, id); // authorizes read, returns DTO or notFound()
  const ability = defineAbilityFor({ id: t.userId, orgRole: t.role as any });
  return (
    <InvoiceHeader
      invoice={invoice}
      canEdit={ability.can('update', subject('Invoice', invoice))}
      canVoid={ability.can('void', subject('Invoice', invoice))}
    />
  );
}
```

## Related Skills
- [admin-panel-architecture](../admin-panel-architecture/Skill.md) — DAL and action structure where enforcement lives
- [multi-tenant-ui](../multi-tenant-ui/Skill.md) — per-org roles and scoping
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — logging grants, denials, privileged actions
- [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md) — state-dependent permissions
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — actions as public endpoints
- [nextjs-authentication](../nextjs-authentication/Skill.md) — sessions feeding the policy
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — broader threat model
- [buttons-and-actions](../buttons-and-actions/Skill.md) — disabled-state UX
- [tooltips](../tooltips/Skill.md) — explaining unavailable actions
- [refine-and-react-admin-frameworks](../refine-and-react-admin-frameworks/Skill.md) — framework access control providers

## Sources
- [Next.js: How to think about data security](https://nextjs.org/docs/app/guides/data-security) — Official — Server Actions reachable by POST, re-auth + IDOR checks, DTOs, return filtering
- [@casl/react README](https://github.com/stalniy/casl/tree/master/packages/casl-react) — Open Source — `<Can>` props, `createContextualCan`, `useAbility`, render-function children, MIT
- [OpenFGA: Perform a check](https://openfga.dev/docs/getting-started/perform-check) — Official — `check`, `batchCheck` with correlation IDs, SDK client config, ReBAC model
- [Permit.io docs](https://docs.permit.io/) — Official — RBAC/ABAC/ReBAC, PDP, `permit.check`, CASL frontend integration
- [W3C WAI-ARIA APG](https://www.w3.org/WAI/ARIA/apg/) — Official — disabled/focusable control guidance

## License / Usage Notes
CASL is MIT; OpenFGA is Apache-2.0; Permit.io is a commercial service with open-source components (check current terms). Content is summarized; code is original. Exact CASL `subject()` usage and ORM adapter APIs should be checked against current docs.

## Quality Tier
A — enforcement model verified against the official Next.js security guide; CASL, OpenFGA and Permit APIs verified from official docs/READMEs; UX rules synthesized from established practice.

## Status
Active

## Last Verified
2026-09-15
