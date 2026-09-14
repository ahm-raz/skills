# Developer Tool UI Patterns

## Summary
UI patterns for products whose users are developers: cloud and hosting consoles, API platforms, observability and logging tools, CI/CD and deployment dashboards, database consoles, and CLIs with web companions. It covers API key and secret management UX, logs and trace viewers, deployment timelines, environment and config editors, code and JSON display, keyboard-first interaction, copyable identifiers, and connecting UI actions to CLI/API equivalents. The implementation assumes React + Next.js.

## Category
Product Patterns

## Subcategories
Developer consoles, API keys and secrets, logs viewers, deployments, environment variables, webhooks management, usage and quotas, CLI parity, code display, keyboard shortcuts

## Problem It Solves
Developer tools are judged on speed, precision, and trust. Generic SaaS UI patterns miss what developers need: exact identifiers that copy cleanly, logs that stream without jank and are searchable, secrets that are never re-displayed, destructive infra actions with safe confirmations, and parity with API/CLI so nothing is click-only. Poor patterns cause incidents, such as deleting production or leaking keys in screenshots.

## When To Use
- Building a developer console, API dashboard, infra/devops product, observability UI, or internal platform portal.
- Adding API keys, webhooks, logs, deployments, or environment config screens to any product.

## When Not To Use
- Public documentation portals: [documentation-site-patterns](../documentation-site-patterns/Skill.md).
- General SaaS shell, billing, members: [saas-application-patterns](../saas-application-patterns/Skill.md) (use together).
- Metric dashboards and charts in depth: [dashboard-design](../dashboard-design/Skill.md).

## Core Principles
1. **Precision over decoration.** Show exact values (IDs, timestamps with timezone, byte sizes, durations) in monospace where alignment matters, and never truncate without a way to see and copy the full value.
2. **Every UI action has an API/CLI equivalent.** Show "View as cURL/CLI" or link to docs. The UI is one client of the public API.
3. **Secrets are write-only after creation.** Show them once, let users copy, then show only a prefix/suffix.
4. **Environment context is always visible.** Production vs staging is unmistakable, and destructive production actions require extra confirmation.
5. **Real-time without chaos.** Streaming data (logs, builds) keeps the reader's scroll position, supports pause/follow, and has no layout jumps.
6. **Keyboard-first.** Command palette, shortcuts, and fast navigation between resources.
7. **Fail loudly and helpfully.** Errors show codes, request IDs, and next steps, and can be copied for support tickets.

## Best Practices
- **Identifiers:** `CopyableId` component showing a readable prefix (`proj_8f3a…c21d`), full value in a tooltip and accessible name, one-click copy with confirmation.
- **Timestamps:** relative ("3 min ago") with absolute ISO/local time + timezone on hover/focus; logs show absolute time with ms precision; allow UTC toggle.
- **API keys page:** table (name, prefix, scopes, created by, created, last used, expires) + "Create key" dialog (name, scopes/permissions, expiry, environment) → reveal-once screen with copy button and explicit "I've saved it" → list. Rotation flow allows overlapping validity.
- **Webhooks:** endpoint list with status (healthy, failing), event subscriptions, signing secret (reveal with re-auth), delivery log with request/response bodies, redeliver button, test event sender.
- **Deployments:** timeline list (commit message, author, branch, status, duration, environment), detail with build logs streaming, promote/rollback actions, links to preview URLs.
- **Logs viewer:** time range picker, query/filter bar with syntax hints and autocomplete, level facets, live tail toggle, virtualized rows, expandable structured JSON, permalink to a log line or query, download/export.
- **Environment variables:** per environment (development/preview/production), masked values with reveal permission, bulk paste of `.env` format, diff before save, redeploy-needed notice.
- **Usage/quotas:** current period usage vs limit with rate-limit headers explanation; alert thresholds configurable.
- **Destructive actions:** type resource name to confirm; show blast radius ("This will delete 3 deployments and 2 domains"); production actions require elevated confirmation or re-auth.
- **Empty states:** show the first command/code snippet to get started ("Install the CLI: `npm i -g acme`").
- **Dark mode** support is expected; ensure syntax and log-level colors meet contrast in both themes.

## Implementation Guidance

### Reveal-once secret flow (Next.js Server Action)
```ts
// app/(app)/w/[ws]/settings/api-keys/actions.ts
"use server";
import { randomBytes, createHash } from "node:crypto";
import { requireMember } from "@/server/auth";
import { db } from "@/server/db";
import { updateTag } from "next/cache";

export async function createApiKey(ws: string, input: { name: string; scopes: string[]; expiresInDays: number | null }) {
  const m = await requireMember(ws, "api_keys:create");                // authz inside the action
  const secret = `sk_live_${randomBytes(24).toString("base64url")}`;
  const hash = createHash("sha256").update(secret).digest("hex");       // store hash only
  await db.apiKey.create({ data: {
    workspaceId: m.workspaceId, name: input.name, scopes: input.scopes,
    prefix: secret.slice(0, 12), last4: secret.slice(-4), hash, createdBy: m.userId,
    expiresAt: input.expiresInDays ? new Date(Date.now() + input.expiresInDays * 864e5) : null,
  }});
  await audit(m, "api_key.created", { name: input.name, scopes: input.scopes });
  updateTag(`ws:${ws}:api-keys`);
  return { secret }; // returned once to this response only; never cached, never logged
}
```
The page must be dynamic. Don't store the secret in client state beyond the reveal dialog, and clear it on close.

### Log streaming architecture
| Concern | Approach |
|---------|----------|
| Transport | SSE (Route Handler returning `ReadableStream`, if host supports streaming duration) or dedicated WebSocket/stream service |
| Rendering | Virtualized list (TanStack Virtual); fixed or measured row heights |
| Follow mode | Auto-scroll only when user is at bottom; show "N new lines ↓ Jump to latest" when scrolled up |
| Buffer | Cap in-memory lines (e.g., 10k); older lines fetched via paginated history API |
| Search | Server-side query for history; client-side highlight within buffer |
| Batching | Buffer incoming lines and flush with `requestAnimationFrame` to keep INP low |

### Environment indicator
```tsx
export function EnvBadge({ env }: { env: "production" | "preview" | "development" }) {
  const label = { production: "Production", preview: "Preview", development: "Development" }[env];
  return <span className={`env env--${env}`} data-env={env}>{label}</span>; // color + text, never color alone
}
```

## Recommended Workflow
1. List resources and the operations developers perform. Map each to an API endpoint and CLI command.
2. Design the resource shell (list/detail) with copyable IDs, timestamps, and environment context.
3. Build secrets flows (create/reveal-once/rotate/revoke) with audit logging.
4. Build streaming views (logs/builds) with virtualization, follow mode, and permalinks.
5. Add "copy as cURL/CLI" affordances and docs links on each resource.
6. Add command palette + shortcuts help (`?`).
7. Harden destructive actions with typed confirmation and production guards.
8. Test with keyboard only, large log volumes, slow networks, and screen readers on core flows.

## Patterns
- **Copy as cURL:** a disclosure on forms showing the equivalent API call built from current inputs, with placeholders for secrets.
- **Permalinked query state:** logs filters, time range, and selected line in URL (`?q=level:error&from=...&line=abc`).
- **Status pill with duration:** `● Building 1m 12s`, `✓ Ready 2m 03s`, `✕ Failed`, with text and icon, not color alone.
- **Request ID surfacing:** error toasts/banners include `Request ID: req_123` with a copy button.
- **Split pane:** list on left, detail/logs on right with a resizable divider (keyboard-resizable).
- **Diff before apply:** config and env changes show added/changed/removed keys before saving.
- **Scoped token builder:** checkboxes grouped by resource with read/write levels and a least-privilege default.

## Anti-Patterns
- **Re-displaying full secrets on a settings page.** Fix: hash at rest; show prefix/last4; rotate instead of reveal.
- **Truncated IDs with no copy.** Fix: `CopyableId`.
- **Auto-scrolling logs while the user reads.** Fix: follow mode only at bottom.
- **Rendering 100k DOM rows.** Fix: virtualization + capped buffer.
- **Same visual treatment for prod and staging.** Fix: persistent environment badge + extra confirmation in prod.
- **UI-only features without API.** Automation is blocked. Fix: API-first; UI calls the same API.
- **Generic "Error occurred".** Fix: error code, message, request ID, docs link.
- **Relative-only timestamps in incident views.** Fix: absolute time with timezone.

## Accessibility
- Streaming logs: don't make the whole log a live region (it floods screen readers). Offer a "new lines" count as a polite status, plus pause.
- Virtualized lists: `role="log"` or a table/grid semantics with `aria-rowcount`/`aria-rowindex` where appropriate; keyboard navigation between rows.
- Status colors (log levels, deploy states) always paired with text or icons (WCAG 1.4.1); contrast ≥ 4.5:1 for text in both themes.
- Keyboard shortcuts: documented, and single-character shortcuts can be turned off or remapped (2.1.4).
- Copy buttons announce success; focus stays in place.
- Resizable panes operable by keyboard (a separator with `aria-valuenow` + arrow keys).
- Code editors (Monaco/CodeMirror): ensure Tab-trapping can be escaped (CodeMirror: Escape then Tab); document it.

## Responsive Design
- Developer consoles are desktop-primary, but on-call engineers use phones. The mobile priorities are deployment status, rollback, logs tail (read-only), and alerts.
- Tables → key columns only on mobile with row drill-in.
- Log lines wrap on mobile with a toggle; horizontal scroll on desktop.

## Performance
- Virtualize large lists and logs; batch stream updates per animation frame.
- Keep JSON viewers lazy: collapse deep objects by default; render on expand.
- Load Monaco/CodeMirror only on routes that need editing (`next/dynamic`).
- Prefetch detail routes on hover in resource tables.
- Measure INP on filter typing and log search.

## Security
- Secrets: generated server-side, hashed at rest (or encrypted if they must be re-used by the platform), shown once, never logged, never placed in URLs.
- Re-authentication (step-up) for revealing signing secrets, deleting production resources, and changing SSO.
- Audit log every key, webhook, env var, and deployment action (see [audit-log-interfaces](../audit-log-interfaces/Skill.md)).
- Redact secrets in logs viewer output server-side (pattern-based masking).
- Webhook test sender must not become an SSRF vector: validate target URLs, block private IP ranges.
- CSRF protection for cookie-authenticated mutations (Server Actions include origin checks; Route Handlers need explicit checks).
- Screenshots/screen-sharing risk: mask values by default with explicit reveal.

## Testing
- Unit: `CopyableId`, timestamp formatting (timezones, DST), env var `.env` parser.
- E2E: create key → reveal once → key not visible after reload → revoke → API call with key fails.
- Stream tests: follow mode behavior, buffer cap, reconnect after disconnect (SSE `Last-Event-ID`).
- Performance: render 50k log lines within budget; INP under typing load.
- Authorization: lower roles can't reveal secrets or delete production resources via API.

## Tooling
- Virtualization: TanStack Virtual.
- Editors: CodeMirror 6 (lighter, accessible options), Monaco (VS Code parity, heavier).
- JSON display: custom collapsible tree or `react-json-view-lite`.
- Syntax highlighting: Shiki (server) for static snippets.
- Command palette: cmdk.
- Terminal emulation (web shells): xterm.js.
- Date/time: `Intl.DateTimeFormat`, Temporal polyfill where needed.

## Framework Notes
- **Next.js App Router (primary):**
  - Resource pages under the workspace-scoped route tree. Lists are Server Components with streaming (`loading.tsx`). Detail panes use parallel routes (`@detail`) for split views with URLs.
  - Secret creation and destructive actions as Server Actions with authorization + audit inside the action.
  - Log streaming via a Route Handler returning an SSE stream (check host limits on duration), or connect the client directly to a streaming backend with a short-lived token minted by a Server Action.
  - Never use `"use cache"` or tagged caching for secret-bearing responses. Mark those segments dynamic.
- **React (Vite SPA):** common for internal platform consoles. Use TanStack Query for resources, EventSource or WebSocket for streams, and TanStack Router search params for log query state. Keep tokens in httpOnly cookies via a BFF.

## AI Agent Guidance
- Treat every identifier, timestamp, and secret with the rules above. Don't render secrets after creation.
- For each new resource screen, add copy-as-cURL/CLI or a docs link and verify the API exists.
- Never paste real tokens into fixtures, stories, or tests. Use obviously fake patterns (`sk_test_EXAMPLE`).
- Verify before done:
  - [ ] Secrets shown once, hashed/encrypted at rest, masked thereafter
  - [ ] Environment clearly indicated; production destructive actions guarded
  - [ ] Long lists/logs virtualized; follow mode respects user scroll
  - [ ] IDs copyable; timestamps absolute on demand with timezone
  - [ ] Actions audited; authorization inside Server Actions/Route Handlers
  - [ ] Keyboard shortcuts documented and disable-able

## Examples

```tsx
// components/copyable-id.tsx
"use client";
import { useState } from "react";

export function CopyableId({ value, label = "ID" }: { value: string; label?: string }) {
  const [copied, setCopied] = useState(false);
  const short = value.length > 16 ? `${value.slice(0, 9)}…${value.slice(-4)}` : value;
  return (
    <span className="copyable-id">
      <code title={value}>{short}</code>
      <button type="button" aria-label={`Copy ${label} ${value}`} onClick={async () => {
        await navigator.clipboard.writeText(value); setCopied(true); setTimeout(() => setCopied(false), 1500);
      }}>{copied ? "Copied" : "Copy"}</button>
      <span role="status" className="sr-only">{copied ? `${label} copied` : ""}</span>
    </span>
  );
}
```

```tsx
// Follow-mode hook for streaming logs
export function useFollowScroll(ref: React.RefObject<HTMLElement>, deps: unknown[]) {
  const atBottom = React.useRef(true);
  React.useEffect(() => {
    const el = ref.current; if (!el) return;
    const onScroll = () => { atBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 24; };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, [ref]);
  React.useLayoutEffect(() => {
    const el = ref.current; if (el && atBottom.current) el.scrollTop = el.scrollHeight;
  }, deps); // eslint-disable-line react-hooks/exhaustive-deps
  return atBottom;
}
```

## Related Skills
- [saas-application-patterns](../saas-application-patterns/Skill.md) — app shell, workspaces, billing
- [documentation-site-patterns](../documentation-site-patterns/Skill.md) — docs links and API reference
- [command-palette](../command-palette/Skill.md) — keyboard navigation
- [keyboard-power-user-ui](../keyboard-power-user-ui/Skill.md) — shortcut systems
- [list-virtualization](../list-virtualization/Skill.md) — large logs and tables
- [realtime-data-ui](../realtime-data-ui/Skill.md) — streaming updates
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — security event trails
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — typed confirmations
- [master-detail-layouts](../master-detail-layouts/Skill.md) — split panes

## Sources
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) — Official/Open — secret lifecycle, rotation, no logging
- [OWASP SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html) — Official/Open — webhook tester URL validation
- [Next.js docs — proxy, revalidateTag/updateTag, Server Actions security](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) — Official — authz inside Server Functions, not proxy alone
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — 1.4.1, 2.1.4, 4.1.3
- [MDN — Server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events) — Official — EventSource reconnection and Last-Event-ID
- Vercel, Stripe, and Linear public dashboards and design writing — Community/vendor — reveal-once keys, environment badges, copy-as-cURL, keyboard-first conventions (observed patterns, not copied)

## License / Usage Notes
Patterns summarized from public guidance and common product conventions; code original.

## Quality Tier
B — Strong security grounding (OWASP, Next.js) but UX conventions derive from observed industry practice rather than published usability research.

## Status
Active

## Last Verified
2026-09-15
