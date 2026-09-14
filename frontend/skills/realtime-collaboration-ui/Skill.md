# Realtime Collaboration UI

## Summary
Patterns for multiplayer features in React/Next.js business apps: presence (avatars, "viewing now"), live cursors and selections, co-editing via CRDTs (Yjs, Liveblocks Storage), soft field locks, conflict resolution for classic records, and reconnect/offline states. It covers choosing between hosted (Liveblocks) and self-hosted (Yjs with a WebSocket provider, PartyKit on Cloudflare) infrastructure, and enforcing room permissions on the server.

## Category
Enterprise UI

## Subcategories
presence, live cursors, CRDT, Yjs, Liveblocks, PartyKit, conflict resolution, optimistic concurrency, comments, offline

## Problem It Solves
When several operators edit the same order, ticket or document, last write wins silently and work is lost. Users also don't know someone else is on the record. Collaboration UI makes others visible, merges concurrent edits safely, and flags conflicts that can't be merged automatically.

## When To Use
- Shared documents, notes, specs, whiteboards, and spreadsheets-like views edited concurrently.
- Records routinely opened by many agents at once (support tickets, dispatch boards).
- Kanban/planning boards where moves should appear live.
- "Who is looking at this" awareness to prevent duplicate handling.

## When Not To Use
- Single-owner records with rare concurrent edits. Optimistic concurrency (a version check) alone is enough.
- Strictly regulated edits that need an approval trail per change. Use workflow-and-approval-ui with explicit submissions, not a free-form CRDT.
- Read-only dashboards needing fresh numbers only. See realtime-data-ui.

## Core Principles
1. Choose the consistency model per data type: CRDT for text/rich content and freeform structures, and server-authoritative records with version checks for business entities with invariants (stock, money, status transitions).
2. The server authorizes room access and every persisted write. Client presence data is untrusted.
3. Presence is ephemeral and cheap. Throttle it and never persist it as business data.
4. Make connection state visible: connected, reconnecting, offline (edits queued), read-only.
5. Never lose user input. On conflict, show both versions and let the user choose or merge.
6. Soft locks inform, they don't secure. A "Maria is editing this field" hint reduces collisions, and the server still validates.

## Best Practices
- Presence: avatar stack in the record header (max about 5 plus "+N"), tooltip with name and what they're doing ("editing Shipping address").
- Field-level focus indicators: a coloured ring plus the name label on the field another user is editing. Colours must be distinguishable and paired with text.
- Live cursors only on canvas-like surfaces (whiteboard, board, spreadsheet). They're noise on forms.
- Throttle cursor and presence updates (roughly 16–100ms depending on provider settings; Liveblocks has a client `throttle` option, check current docs).
- Business records: include `version` (or `updatedAt`) in every update. The server rejects stale writes (HTTP 409 / action result `conflict`), and the UI shows a diff dialog.
- Broadcast "record changed" events so other viewers can refresh (`router.refresh()` in Next.js) instead of silently viewing stale data.
- Comments and mentions are often the highest-value collaboration feature. Liveblocks ships comment/notification primitives. Otherwise build on your own DB.
- Provide undo scoped to the local user's changes (Yjs `UndoManager` tracks local origins).
- Show "You're offline — changes will sync" and disable actions that require the server (approve, pay).

## Implementation Guidance
**Infrastructure decision table**

| Option | Model | Good for | Notes |
|---|---|---|---|
| Liveblocks | Hosted rooms: presence, broadcast, Storage (conflict-free `LiveObject`/`LiveList`/`LiveMap`), Yjs support, comments/notifications | Fast delivery, React hooks, Next.js auth route | Commercial SaaS with free tier (check pricing). Data leaves your infra |
| Yjs + y-websocket / y-indexeddb | Open-source CRDT (MIT) with pluggable providers and awareness protocol | Self-hosting, editor bindings (Tiptap, ProseMirror, CodeMirror, Monaco) | You operate the WebSocket server, persistence and auth |
| PartyKit / Cloudflare | Stateful rooms on Durable Objects. `y-partykit` for Yjs | Edge-hosted rooms with custom server logic | Cloudflare acquired PartyKit (announced April 2024). Check current docs for partyserver vs PartyKit platform |
| Your DB + SSE/WebSocket events | Server-authoritative records, change notifications | ERP/CRM records with invariants | Pair with version checks; no CRDT |

**Liveblocks in Next.js App Router (shape)**
1. `app/api/liveblocks-auth/route.ts`: authenticate the session, look up which rooms the user may access (tenant, record permission), then `prepareSession(user.id, { userInfo })`, `session.allow(roomPattern, session.READ_ACCESS | FULL_ACCESS)` and `authorize()`.
2. The client `LiveblocksProvider authEndpoint="/api/liveblocks-auth"` wraps `RoomProvider id={`tenant:${tenantId}:order:${id}`}`, with `ClientSideSuspense` for the loading fallback.
3. Hooks: `useOthers`, `useMyPresence`/`useUpdateMyPresence`, `useStorage`, `useMutation`, `useStatus` (connection state; verify the hook name in current docs).
4. Define `Presence`, `Storage` and `UserMeta` types in `liveblocks.config.ts` global declarations.

**Yjs primitives**
- `Y.Doc` with shared types `Y.Map`, `Y.Array`, `Y.Text`. Changes merge automatically.
- Providers: `y-websocket` (server sync), `y-webrtc` (peer), `y-indexeddb` (local persistence/offline).
- `provider.awareness` for presence (cursor, selection, user). Awareness state is ephemeral.
- Editor bindings (Tiptap Collaboration extension, y-prosemirror, y-codemirror) handle cursors and selections.

## Recommended Workflow
1. Classify data: CRDT-able (text, layout, board order) vs server-authoritative (status, amounts, inventory).
2. Choose the provider. Define the room naming convention including tenant: `tenant:{t}:{resource}:{id}`.
3. Implement the auth endpoint with record-level permission checks. Add read-only rooms for viewers.
4. Add presence (avatars) first, then field focus indicators, then co-editing, then comments.
5. Implement version-checked mutations plus a conflict dialog for records.
6. Add a connection status indicator and offline handling. Test with network throttling and two browsers.
7. Persist CRDT snapshots server-side and record audit events for business-relevant changes.

## Patterns
**Room provider (client)**
```tsx
'use client';
import { LiveblocksProvider, RoomProvider, ClientSideSuspense } from '@liveblocks/react/suspense';

export function RecordRoom({ roomId, children }: { roomId: string; children: React.ReactNode }) {
  return (
    <LiveblocksProvider authEndpoint="/api/liveblocks-auth">
      <RoomProvider id={roomId} initialPresence={{ focusedField: null }}>
        <ClientSideSuspense fallback={<PresencePlaceholder />}>{children}</ClientSideSuspense>
      </RoomProvider>
    </LiveblocksProvider>
  );
}
```

**Auth route handler with server-side permission**
```ts
// app/api/liveblocks-auth/route.ts
import { Liveblocks } from '@liveblocks/node';
import { getCurrentUser, canAccessRecord } from '@/data/auth';

const liveblocks = new Liveblocks({ secret: process.env.LIVEBLOCKS_SECRET_KEY! });

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return new Response('Unauthorized', { status: 401 });
  const { room } = (await req.json()) as { room?: string };
  const access = room ? await canAccessRecord(user, room) : 'none'; // parses tenant/resource/id, checks DAL
  if (access === 'none') return new Response('Forbidden', { status: 403 });

  const session = liveblocks.prepareSession(user.id, { userInfo: { name: user.name, color: user.color } });
  session.allow(room!, access === 'write' ? session.FULL_ACCESS : session.READ_ACCESS);
  const { status, body } = await session.authorize();
  return new Response(body, { status });
}
```

**Field focus indicator**
```tsx
'use client';
import { useOthers, useUpdateMyPresence } from '@liveblocks/react/suspense';

export function CollabField({ name, label, children }: { name: string; label: string; children: React.ReactElement }) {
  const editors = useOthers((others) => others.filter((o) => o.presence.focusedField === name).map((o) => o.info));
  const update = useUpdateMyPresence();
  return (
    <div onFocus={() => update({ focusedField: name })} onBlur={() => update({ focusedField: null })}
         data-editing={editors.length > 0 || undefined} className="collab-field">
      <label htmlFor={name}>{label}</label>
      {children}
      {editors.length > 0 && <span className="collab-badge">{editors.map((e) => e?.name).join(', ')} editing</span>}
    </div>
  );
}
```

**Optimistic concurrency for records (non-CRDT)**
```ts
'use server';
import { updateOrder } from '@/data/orders';
export async function saveOrder(_: unknown, formData: FormData) {
  const res = await updateOrder({ id: String(formData.get('id')), version: Number(formData.get('version')), patch: parseOrder(formData) });
  // DAL: authz, then UPDATE ... WHERE id = ? AND version = ?; 0 rows -> conflict with latest snapshot
  return res.ok ? { status: 'saved' as const } : { status: 'conflict' as const, latest: res.latest };
}
```
On `conflict`, open a dialog: "Alex changed Status and Delivery date 2 minutes ago", show mine vs theirs per field, keep my unsaved input, and offer "Apply theirs", "Overwrite with mine" (re-submit with the new version) or a per-field merge.

## Anti-Patterns
- **Room access checked only by room id on the client.** Anyone can join any room. Fix: the auth endpoint checks tenant and record permissions and issues scoped tokens.
- **Using a CRDT for invariant-bound fields (stock, balance).** Merges can violate business rules. Fix: server-authoritative mutations with validation.
- **Persisting presence** or sending cursor moves on every `pointermove`. Fix: ephemeral presence, throttled.
- **Hard locks with no expiry.** Records stay locked when a tab dies. Fix: soft locks via presence, which disappear on disconnect, plus server version checks.
- **Silent last-write-wins.** Fix: version checks and a conflict UI.
- **No connection state.** Users edit offline believing it's saved. Fix: a status indicator plus disabled server-only actions.
- **Secret key in client code.** Fix: secret keys only in route handlers or server env. Public keys only for prototyping.

## Accessibility
- Presence avatars: accessible names ("Maria Lopez, editing Shipping address"), not colour-only identity (WCAG 1.4.1).
- Announce joins/leaves sparingly. Prefer an on-demand "who's here" list over constant live-region chatter. Remote edits to the field the user is focused on must not steal focus or move the caret.
- Conflict dialogs follow accessible-dialogs rules. Diff uses text labels ("Theirs"/"Mine"), not just red/green.
- Live cursors are decorative for AT (`aria-hidden`). Offer a textual activity feed instead.
- Connection status uses a `role="status"` region.

## Responsive Design
- Collapse the avatar stack to a count on narrow headers.
- Hide live cursors on touch devices. Keep field indicators.
- The conflict dialog becomes a full-screen sheet on mobile, with a stacked mine/theirs layout.

## Performance
- Subscribe to narrow slices: `useOthers(selector)` and `useStorage(selector)` to avoid rerendering the whole form on every presence tick.
- Throttle presence and use `requestAnimationFrame` for cursor rendering with CSS transforms.
- Lazy-load collaboration bundles (`next/dynamic`) only on collaborative pages.
- Snapshot and compact Yjs documents server-side. Large update histories slow initial sync.
- Limit room size and paginate presence lists on huge boards.

## Security
- Authorize per room in the auth endpoint (tenant plus record permission), and issue read-only tokens for viewers.
- Validate and re-authorize persisted changes server-side (webhooks or server sync). Don't trust client-sent `userInfo`: set it on the server from the session.
- Keep `LIVEBLOCKS_SECRET_KEY` and similar server-only. Rotate on exposure.
- Room names must not leak sensitive data (use ids, not customer names).
- Data residency and retention: review hosted provider terms for regulated data.

## Testing
- Playwright with two browser contexts: user A focuses a field, and B sees the indicator. A edits, and B receives it.
- Conflict test: both load v1, A saves, B saves, B sees the conflict dialog with A's values, and B's input is preserved.
- Offline: `context.setOffline(true)`, edit, reconnect, and assert the sync and status indicator.
- Authorization: a user from another tenant hits the auth endpoint with the room id and gets 403.
- Unit: room-name parser and permission mapping.

## Tooling
- Liveblocks (`@liveblocks/client`, `@liveblocks/react`, `@liveblocks/node`, optional Yjs integration). Commercial, with free tier.
- Yjs (MIT) with `y-websocket`, `y-webrtc`, `y-indexeddb`, and editor bindings.
- PartyKit / `partysocket` / `y-partykit`, now under Cloudflare (Durable Objects). Check current docs for the recommended package.
- Alternatives to evaluate: Automerge, Hocuspocus (Tiptap), Supabase Realtime presence, Ably/Pusher. Check current docs.

## Framework Notes
- **React (Vite SPA):** providers wrap routed pages. The auth endpoint lives on your API server with the same permission checks.
- **Next.js App Router:** the Server Component page loads the record via the DAL (authz) and passes the room id and initial snapshot to the client `RecordRoom`. The auth endpoint is a route handler. Record saves are Server Actions with version checks, then `revalidatePath`, plus a broadcast event so peers call `router.refresh()`. Don't run WebSocket servers inside Next.js route handlers on serverless hosts. Use a provider or a separate service.

## AI Agent Guidance
- Do: classify fields (CRDT vs authoritative), namespace rooms by tenant, implement the auth route with DAL checks, throttle presence, add a connection status and a conflict dialog.
- Don't: expose secret keys, use hard locks, persist presence, or let the client set its own identity/colour.
- Verify: two-context E2E passes, a cross-tenant join is rejected, an offline edit reconciles, and screen readers aren't spammed by presence updates.

## Examples
```tsx
'use client';
import { useOthers, useStatus } from '@liveblocks/react/suspense';

export function PresenceBar() {
  const others = useOthers((o) => o.map((u) => ({ id: u.connectionId, name: u.info?.name ?? 'Guest', field: u.presence.focusedField })));
  const status = useStatus(); // verify exact hook name/values in current Liveblocks docs
  return (
    <div className="presence-bar">
      <ul aria-label="People viewing this record">
        {others.slice(0, 5).map((u) => (
          <li key={u.id} title={u.field ? `${u.name}, editing ${u.field}` : u.name}>
            <span className="avatar" aria-hidden>{u.name[0]}</span>
            <span className="sr-only">{u.field ? `${u.name}, editing ${u.field}` : u.name}</span>
          </li>
        ))}
        {others.length > 5 && <li>+{others.length - 5}</li>}
      </ul>
      <span role="status">{status === 'connected' ? '' : 'Reconnecting… changes will sync'}</span>
    </div>
  );
}
```

## Related Skills
- [realtime-data-ui](../realtime-data-ui/Skill.md) — streaming data transport (SSE/WebSocket) for non-collaborative updates
- [optimistic-ui](../optimistic-ui/Skill.md) — optimistic updates and rollback
- [kanban-boards](../kanban-boards/Skill.md) — live board moves
- [rich-text-editors](../rich-text-editors/Skill.md) — Yjs editor bindings
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — recording collaborative changes
- [multi-tenant-ui](../multi-tenant-ui/Skill.md) — tenant-scoped rooms
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — auth endpoint
- [accessible-dialogs](../accessible-dialogs/Skill.md) — conflict resolution dialog
- [service-workers-and-offline](../service-workers-and-offline/Skill.md) — offline queues

## Sources
- [Liveblocks Next.js get started](https://liveblocks.io/docs/get-started/nextjs) — Official — providers, ClientSideSuspense, useStorage/useMutation/useOthers/useMyPresence
- [Liveblocks access token auth (Next.js)](https://liveblocks.io/docs/authentication/access-token/nextjs) — Official — prepareSession, allow, authorize route handler
- [Yjs docs](https://docs.yjs.dev/) — Open Source — shared types, providers, network-agnostic CRDT, editor bindings
- [PartyKit docs](https://docs.partykit.io/) — Official — Party.Server, PartySocket, y-partykit
- [Cloudflare acquires PartyKit](https://blog.cloudflare.com/cloudflare-acquires-partykit/) — Official — acquisition (April 2024), Durable Objects basis
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — server-side authz for actions and route handlers

## License / Usage Notes
Yjs is MIT. Liveblocks is a commercial service with open-source client packages (check the package licenses). PartyKit is under Cloudflare, so check current terms. Content is summarized. Code is original, and hook names marked "verify" should be checked against current docs.

## Quality Tier
B — core provider facts verified. Some hook names (`useStatus`, `useUpdateMyPresence`) and the current PartyKit/partyserver packaging were not re-verified this session.

## Status
Active

## Last Verified
2026-09-15
