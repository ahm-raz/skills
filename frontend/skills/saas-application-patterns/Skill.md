# SaaS Application Patterns

## Summary
Structural and UX patterns for authenticated, multi-user B2B/B2C SaaS web applications. It covers the app shell, workspace/tenant switching, navigation, list–detail–edit flows, onboarding and activation, settings, members and roles, billing and plan limits, notifications, and the technical architecture behind them (routing, data layer, auth boundary, feature entitlements, observability). It is the connective layer between individual components and a coherent product.

## Category
Product Patterns

## Subcategories
App shell, workspaces and tenancy, entitlements and plan gating, billing portal, team management, onboarding/activation, settings, notifications, command palette, product analytics

## Problem It Solves
SaaS apps grow feature by feature until navigation is inconsistent, every page handles loading and errors differently, and plan limits are enforced only in the UI. Tenant context leaks through stale caches, and upgrade and billing flows are bolted on. This skill defines the standard skeleton and rules so new features slot in consistently and safely.

## When To Use
- Building a new SaaS product or restructuring an existing app shell.
- Adding workspaces/organizations, team invites, roles, or plan-based feature gating.
- Designing billing, upgrade, trial-expiry, and usage-limit experiences.
- Standardizing list/detail/create/edit flows across resources.

## When Not To Use
- Heavy internal/admin tooling with dense tables and CRUD over many entities: [admin-panel-architecture](../admin-panel-architecture/Skill.md).
- Public marketing pages: [marketing-website-architecture](../marketing-website-architecture/Skill.md).
- Developer-facing consoles (API keys, logs, deploys): combine with [developer-tool-ui-patterns](../developer-tool-ui-patterns/Skill.md).

## Core Principles
1. **Tenant context is explicit.** The current workspace lives in the URL (`/w/:workspaceSlug/...`), not only in client state, so links, reloads, and multiple tabs behave correctly.
2. **The server is the authority.** Permissions, entitlements, and limits are enforced by the API. The UI mirrors them to guide users, never to secure.
3. **Consistent resource grammar.** Every resource follows the same index → detail → create/edit → delete flow with the same states.
4. **Time to value first.** Onboarding drives the one activation action that predicts retention. Setup that isn't required is deferred.
5. **Upgrade paths are contextual and honest.** Show gated features with a clear explanation and path, at the moment of need.
6. **Every screen has four states:** loading, empty, error, and populated. Design all four.
7. **Keyboard and URL are first-class.** Deep links for everything shareable; power-user shortcuts and a command palette for frequent actions.

## Best Practices
- **App shell:** persistent sidebar (workspace switcher at top, primary nav, secondary "Settings"/"Help" at bottom, user menu) + top bar (breadcrumbs/page title, search/command, notifications). Collapse the sidebar to icons or a drawer on small screens.
- **Workspace switcher:** shows current workspace name and avatar, lists workspaces with role, and includes "Create workspace". Switching navigates to the new workspace URL and clears tenant-scoped caches.
- **Navigation depth:** 5–9 primary items; group the rest under sections. Don't nest more than two levels in the sidebar.
- **Resource index:** title + primary "New X" button + search/filter + table or cards + pagination. Filter, sort, and page state live in the URL query string.
- **Detail pages:** header (name, status, primary actions, overflow menu) + tabs for sub-areas, each a real route (`/projects/:id/settings`).
- **Create flows:** short forms in a dialog; long or multi-step forms on a dedicated page. After create, navigate to the new resource.
- **Destructive actions:** confirm with object name; offer undo or soft delete where feasible.
- **Settings IA:** split into Personal (profile, notifications, security) and Workspace (general, members, billing, integrations, API, danger zone), then gate each by role.
- **Members:** invite by email with role; pending invites listed with resend/revoke; last-owner protection; SSO/SCIM-managed users marked read-only.
- **Billing:** current plan, usage vs limits (meter), next invoice date and amount, payment method, invoices, change plan, cancel. Use the payment provider's hosted portal for card updates when possible.
- **Trials:** show days remaining in a non-nagging place, and send email before expiry. On expiry, go read-only rather than deleting data.
- **Notifications:** in-app inbox for durable events; toasts only for immediate feedback on the user's own actions; user-controllable email preferences.

## Implementation Guidance

### Route structure
```
/login, /signup, /invite/:token          (public, unauthenticated)
/onboarding                              (authenticated, no workspace yet)
/w/:ws                                   → redirect to /w/:ws/home
/w/:ws/home
/w/:ws/projects                          index
/w/:ws/projects/new                      create
/w/:ws/projects/:id                      detail (overview tab)
/w/:ws/projects/:id/activity             detail tab
/w/:ws/settings/general|members|billing|integrations|api-keys
/account/profile|security|notifications  (user-scoped, workspace-independent)
```

### Entitlements model (mirror in UI, enforce in API)
```ts
// shared/entitlements.ts
export type Plan = "free" | "pro" | "enterprise";
export type Feature = "sso" | "auditLog" | "advancedReports" | "apiAccess";
export type Limit = "seats" | "projects" | "storageGb";

export interface Entitlements {
  plan: Plan;
  features: Record<Feature, boolean>;
  limits: Record<Limit, { used: number; max: number | null }>; // null = unlimited
  role: "owner" | "admin" | "member" | "viewer";
  permissions: string[]; // e.g. "projects:create", "billing:manage"
}

// Fetched once per workspace (server), cached per workspace key, invalidated on plan/role change.
```

```tsx
// ui/Gate.tsx — guides the user; the API still returns 403/402 if bypassed
export function FeatureGate({ feature, children, fallback }: { feature: Feature; children: React.ReactNode; fallback?: React.ReactNode }) {
  const ent = useEntitlements();
  if (ent.features[feature]) return <>{children}</>;
  return fallback ?? <UpgradeCallout feature={feature} canManageBilling={ent.permissions.includes("billing:manage")} />;
}
```
`UpgradeCallout` must tell non-admins who to ask ("Ask a workspace admin to upgrade"). Only billing managers see the upgrade button.

### Data layer rules
| Concern | Rule |
|---------|------|
| Query keys | Always include workspace ID: `["ws", wsId, "projects", filters]` |
| Workspace switch | Clear or scope caches; cancel in-flight requests |
| Mutations | Invalidate affected lists; optimistic only for low-risk, reversible changes |
| 401 | Redirect to login preserving return URL |
| 403 | Render "no access" state with who to contact, not a blank page |
| 402/limit reached | Render limit state with usage and upgrade path |
| 404 | Resource-level not found inside the shell (keep navigation) |

### Onboarding/activation
1. Define the activation event (e.g., "created first project and invited one teammate").
2. Minimal signup (email/SSO) → create workspace (name only) → land on an empty state whose primary CTA is the activation action.
3. Optional checklist (3–5 items), dismissible, persisted server-side.
4. Sample data or templates to avoid a blank first screen, clearly labeled and easy to remove.

## Recommended Workflow
1. List resources, roles, plans, and the activation event.
2. Define route map with workspace scoping and settings IA.
3. Build app shell + auth boundary + entitlements provider.
4. Implement one resource end to end (index/detail/create/edit/delete with all states) as the reference pattern.
5. Add members/invites, then billing via provider portal/checkout.
6. Add notifications, command palette, keyboard shortcuts.
7. Instrument product analytics (activation funnel, feature adoption) and error monitoring with workspace/user context (no PII in event names).
8. Test role × plan matrix end to end.

## Patterns
- **Resource page scaffold:** `PageHeader(title, actions) → Toolbar(search, filters, view) → Content(state machine: loading|empty|error|data) → Pagination`.
- **Empty state as onboarding:** illustration optional; one-sentence value, primary CTA, secondary "Import" or "Use template".
- **Usage meter:** `<meter>` or progress with text "7 of 10 projects". Warn at 80%, block at 100% with upgrade path.
- **Danger zone:** separated section at bottom of settings; typed confirmation for delete workspace.
- **Impersonation banner:** support staff viewing as user see a persistent, high-contrast banner with exit; all actions audited.
- **Unsaved changes guard:** warn on navigation when a form is dirty.
- **Cross-tab session sync:** BroadcastChannel to propagate logout/workspace deletion.

## Anti-Patterns
- **Workspace ID only in localStorage.** Shared links open the wrong tenant, and data can cross-contaminate. Fix: workspace in URL; validate membership server-side.
- **Hiding gated features entirely.** Users never discover upgrades. Fix: show with a lock + explanation where discovery matters (hide only admin-only destructive items from non-admins).
- **UI-only permission checks.** Fix: API enforcement + UI mirror + tests calling the API directly as lower roles.
- **Upgrade modal on every click.** Hostile. Fix: contextual, dismissible, frequency-capped.
- **Cancel flow maze.** Deceptive and, in many jurisdictions, regulated. Fix: cancellation reachable in settings in about as many steps as signup. An optional retention offer is shown once.
- **Toast for errors that need action.** It disappears. Fix: inline error or banner that persists until resolved.
- **Global spinner blocking the shell.** Fix: keep the shell rendered; show skeletons in content areas.

## Accessibility
- Landmarks: `nav` for sidebar (labelled), `main` for content, `header` for top bar.
- Route changes: move focus to the page H1 or announce the new page title (see [accessible-spa-routing](../accessible-spa-routing/Skill.md)).
- Command palette and shortcuts: discoverable (help dialog), remappable or disable-able single-key shortcuts (WCAG 2.1.4).
- Status messages (saved, invite sent) via polite live region (4.1.3).
- Tables use real table semantics; sortable headers use `aria-sort`.
- Session timeout: warn before expiry with option to extend (2.2.1).

## Responsive Design
- Sidebar → off-canvas drawer below ~1024px; bottom tab bar only if there are four or five primary destinations used on mobile.
- Tables → prioritized columns or card lists on narrow screens; keep row actions reachable.
- Settings: two-pane (section list + content) on desktop, drill-in on mobile.
- Dialog-based create flows become full-screen sheets on small screens.

## Performance
- Split by route; the shell loads once, and feature routes lazy-load.
- Prefetch likely next routes on hover/visible links.
- Cache entitlements and current-user data; don't refetch on every navigation.
- Virtualize long lists; paginate server-side for large datasets.
- Measure INP on heavy interactions (filters, bulk selects).

## Security
- Auth tokens in httpOnly, Secure, SameSite cookies or via a BFF; avoid long-lived tokens in localStorage (see [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md)).
- Every API call is authorized against the workspace in the path; never trust a workspace ID from the client without a membership check.
- Invite tokens: single-use, expiring, bound to email.
- API keys displayed once at creation; afterwards only prefix shown.
- CSRF protection for cookie-authenticated mutations.
- Log security events (role change, SSO config, key creation) to audit log.

## Testing
- Role × plan matrix: E2E smoke per role (owner/admin/member/viewer) and plan (free/pro/enterprise).
- API authorization tests independent of UI.
- Workspace switch test: data from workspace A never visible after switching to B (cache isolation).
- Every resource page: loading, empty, error, populated states via mocked API (MSW).
- Billing flows against provider test mode; webhook-driven plan changes reflected in UI.

## Tooling
- Data: TanStack Query or framework loaders; tRPC/OpenAPI-generated clients.
- Auth: Auth.js, Clerk, WorkOS, Auth0, Supabase Auth, Better Auth; SSO/SCIM via WorkOS or similar for enterprise.
- Billing: Stripe Billing + Customer Portal, Paddle, Lemon Squeezy, Chargebee; entitlement services (e.g., Stripe Entitlements, Schematic, Stigg).
- Product analytics: PostHog, Amplitude, Mixpanel. Errors: Sentry.
- UI kits: shadcn/ui, Radix, React Aria, Mantine.

## Framework Notes
- **Next.js App Router (primary):**
  - `app/(app)/w/[ws]/layout.tsx` loads the session, membership, and entitlements server-side, as in the example. Auth, onboarding, and marketing live in separate route groups with their own layouts.
  - Don't rely on layouts alone for authorization. Layouts don't re-run on every client navigation, and Server Actions and Route Handlers are directly callable. Re-check session and membership inside every Server Action, Route Handler, and data-access function (a `server-only` DAL module).
  - `proxy.ts` (formerly `middleware.ts`) is for optimistic redirects, such as sending users without a session cookie to `/login`. It is never the only check.
  - Settings as nested layout `w/[ws]/settings/layout.tsx` with a section nav; each section is its own route.
  - Create-in-modal with a shareable URL: intercepting route `@modal/(.)projects/new` + parallel route slot, with `projects/new/page.tsx` as the full-page fallback.
  - Mutations via Server Actions, then `revalidatePath`/`updateTag` for the affected lists. `useOptimistic` only for low-risk changes.
  - Per-user pages are dynamic. Never cache tenant data under a key that lacks the workspace ID.
  - `loading.tsx` per segment keeps the shell visible while content streams. `error.tsx` and `not-found.tsx` sit inside the workspace segment so navigation survives.
- **React (Vite SPA + React Router or TanStack Router):** the workspace param lives in the route path. TanStack Query keys include `wsId`. Call `queryClient.removeQueries({ queryKey: ["ws", prevWs] })` on switch. A route-level `beforeLoad`/loader fetches entitlements. Keep the API behind a BFF so tokens stay in httpOnly cookies.

## AI Agent Guidance
- Before building a feature, identify: which workspace scope, which roles can see or act, which plan gates it, and all four screen states.
- Always add API-side authorization when adding a UI permission check. Never ship a UI-only gate.
- Reuse the reference resource page scaffold; don't invent new page layouts per feature.
- Verify before done:
  - [ ] Route includes workspace; reload and deep link work
  - [ ] Loading/empty/error/populated states implemented
  - [ ] Lower-privileged role gets correct UI and API denial
  - [ ] Query cache keys include workspace ID
  - [ ] Focus/announcement on route change; keyboard operable
  - [ ] Analytics event for the feature's key action added without PII

## Examples

```tsx
// app/w/[ws]/layout.tsx — Next.js: membership + entitlements at the boundary
import { notFound, redirect } from "next/navigation";
import { getSession } from "@/server/auth";
import { getMembership, getEntitlements } from "@/server/workspaces";
import { AppShell } from "@/ui/app-shell";
import { EntitlementsProvider } from "@/ui/entitlements";

export default async function WorkspaceLayout({ children, params }: { children: React.ReactNode; params: Promise<{ ws: string }> }) {
  const { ws } = await params;
  const session = await getSession();
  if (!session) redirect(`/login?next=/w/${ws}`);
  const membership = await getMembership(session.userId, ws);
  if (!membership) notFound(); // don't reveal workspace existence
  const entitlements = await getEntitlements(membership.workspaceId, membership.role);
  return (
    <EntitlementsProvider value={entitlements}>
      <AppShell workspace={membership.workspace} user={session.user}>{children}</AppShell>
    </EntitlementsProvider>
  );
}
```

```tsx
// Usage meter with accessible text
<div>
  <label htmlFor="proj-usage">Projects</label>
  <meter id="proj-usage" min={0} max={10} low={8} high={9} optimum={0} value={7}>7 of 10</meter>
  <span>7 of 10 used</span>
</div>
```

## Related Skills
- [multi-tenant-ui](../multi-tenant-ui/Skill.md) — tenant isolation details
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — RBAC UI mirroring
- [onboarding-ux](../onboarding-ux/Skill.md) — activation flows
- [settings-and-preferences-ux](../settings-and-preferences-ux/Skill.md) — settings IA
- [empty-states](../empty-states/Skill.md), [loading-states](../loading-states/Skill.md), [error-states](../error-states/Skill.md) — required screen states
- [command-palette](../command-palette/Skill.md) — power navigation
- [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md) — app shell navigation
- [pricing-page-patterns](../pricing-page-patterns/Skill.md) — plan structure mirrored in billing
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — session security
- [admin-panel-architecture](../admin-panel-architecture/Skill.md) — internal tools counterpart

## Sources
- [Stripe Docs — Online payments / Checkout Sessions](https://docs.stripe.com/payments/online-payments) — Official — hosted vs embedded billing flows, webhook lifecycle
- [NN/g — articles on empty states, onboarding, and B2B usability](https://www.nngroup.com/reports/b2b-websites-usability/) — Official research — state design, explicit differences
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — status messages, timing, character key shortcuts
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — Official/Open — server-side enforcement, deny by default
- Linear and Vercel public product/design writing (linear.app/method, vercel.com/design) — Community/Vendor — keyboard-first, command menu, workspace-in-URL conventions
- Community AGENTS.md/.cursor/rules for SaaS starters — Community — recurring rules: server-side auth checks, tenant-scoped queries

## License / Usage Notes
Patterns summarized in original words; code original. Vendor names are trademarks of their owners.

## Quality Tier
A — Synthesizes official security/accessibility guidance with widely converged SaaS conventions; no single canonical standard exists for SaaS structure.

## Status
Active

## Last Verified
2026-09-15
