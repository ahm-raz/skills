# Realtime Data UI

## Summary
Patterns for UIs that display continuously changing data: live charts, metrics tiles, tickers, logs, and status boards. It covers transport choice (polling, Server-Sent Events, WebSockets, WebSocketStream), connection lifecycle (reconnect, backoff, resume), backpressure and throttling (coalescing messages into render frames), bounded buffers, stale/offline indicators, and accessible live updates, implemented in React and Next.js.

## Category
Data Visualization

## Subcategories
WebSockets, SSE/EventSource, polling, backpressure, throttling, ring buffers, useSyncExternalStore, live charts, connection status, Next.js route handlers

## Problem It Solves
Naive live UIs call `setState` per message, re-render whole dashboards at hundreds of Hz, and grow arrays without bound. They also reconnect in tight loops, lose messages on reconnect, and silently show stale data. The result is jank, memory leaks, battery drain, and wrong decisions.

## When To Use
- Monitoring/ops dashboards, trading or pricing tickers, IoT telemetry, live logs, and progress feeds.
- Any chart receiving more than about one update per second.

## When Not To Use
- Data that changes every few minutes: use polling or revalidation (TanStack Query `refetchInterval`, Next.js revalidate).
- Collaborative editing/presence: see realtime-collaboration-ui (CRDTs, presence).
- Notifications only: toasts-and-notifications.

## Core Principles
1. **Pick the simplest transport that fits:**
   - Polling: under 1 update per 10s, or cache-friendly data.
   - SSE: server-to-client only, text, auto-reconnect, `Last-Event-ID` resume.
   - WebSocket: bidirectional, binary, high frequency.
2. **Decouple message rate from render rate.** Ingest into a mutable buffer/store, and render at most once per animation frame (or 1–4 Hz for dashboards humans read).
3. **Bound everything.** Ring buffers or time windows for series, capped log lines, and dropped/merged intermediate updates for "latest value" data.
4. **Backpressure:** if the client can't keep up, conflate (keep latest per key), sample, or ask the server to reduce the rate. Never queue unboundedly.
5. **Connection state is UI state.** Show connecting, live, reconnecting, stale since T, and paused.
6. **Resume correctly.** Use sequence ids / `Last-Event-ID` and snapshot + delta on reconnect, with idempotent merges.
7. **Pause when hidden.** Throttle or disconnect when `document.visibilityState === 'hidden'`, and resync on return.
8. **Accessibility:** users can pause; announcements are throttled, polite, and opt-in.

## Best Practices
- **SSE:**
  - Send `id:` on every event and `retry:` to set reconnect delay. Heartbeat comments (`: ping`) every 15–30s keep proxies from closing idle connections.
  - HTTP/1.1 caps about 6 SSE connections per browser per origin (won't-fix in Chrome/Firefox). Use HTTP/2+ or multiplex topics over one stream.
- **WebSocket:**
  - Implement heartbeat ping/pong and exponential backoff with jitter (for example, 0.5s → 30s max), and resubscribe topics after reconnect.
  - Check `bufferedAmount` before sending bursts.
- **WebSocketStream** gives built-in backpressure via Streams, but is Chrome-only as of 2026. Feature-detect and fall back to WebSocket.
- **Binary formats** (MessagePack, Protobuf, Arrow IPC) for high-rate numeric data. Decode in a Web Worker when parsing is heavy.
- **Store outside React:** a tiny external store (subscribe/getSnapshot) consumed with `useSyncExternalStore`, with snapshots updated at most once per frame. This avoids tearing in concurrent rendering.
- **Charts:**
  - Disable animations. Use canvas libraries (uPlot, Chart.js with `update('none')`, ECharts `appendData`/`setOption` with `lazyUpdate`) for more than a few hundred updates per minute.
  - Fix axis domains or ease them to avoid jittery rescaling.
- **Stale indicators:** show "Last update 12s ago" and switch to a warning style when older than 2–3× the expected interval.
- **User control:** a Pause/Resume live button. Pause automatically while the user hovers, brushes, or zooms a chart, and show "N new updates" to resume.
- **Time:** use server timestamps (not client receipt time) for the x-axis, and display the timezone.
- **Security:** authenticate the connection (cookie with origin check, or a short-lived token), authorize per topic, and validate every message with a schema.

## Implementation Guidance
**Transport decision table**

| Need | Choose |
|---|---|
| Update ≤ every 10–30s, cacheable | Polling (TanStack Query `refetchInterval`, pause when hidden) |
| Server → client stream, text/JSON, resume needed | SSE (`EventSource`) |
| Bidirectional, binary, > 10 msg/s, subscriptions | WebSocket (+ WebSocketStream where supported) |
| Hosted serverless with duration limits | Managed realtime service (Pusher/Ably/Supabase Realtime/Liveblocks) or a separate long-lived server |
| Very high-rate numeric telemetry | WebSocket + binary + worker decode + canvas chart |

**Render-rate targets**

| Content | Max UI update rate |
|---|---|
| KPI numbers humans read | 1–2 Hz (numbers flickering faster are unreadable) |
| Live line chart | 10–30 fps (rAF-coalesced), 60 fps only for smooth scrolling telemetry |
| Log/event list | batch append every 250–500ms, virtualized |
| Status badges | on change only, debounced 1s against flapping |

## Recommended Workflow
1. Define data semantics: latest value per key (conflatable) or event log (every event matters)?
2. Choose the transport and message schema (with sequence ids) and a snapshot endpoint.
3. Build a connection manager: connect, heartbeat, backoff, resubscribe, visibility handling, status events.
4. Build a bounded store (ring buffer or conflation map) with rAF-coalesced notifications.
5. Bind React via `useSyncExternalStore`, and render with a canvas chart with animations off.
6. Add a status indicator, stale detection, pause/resume, and "N new" affordances.
7. Add accessible summaries (throttled polite live region, opt-in).
8. Load test: simulate 10× expected message rate, check dropped frames (Performance panel), memory flat over 30 minutes, and reconnect storms.

## Patterns
- **Ring buffer** of typed arrays for time series (`Float64Array` x, `Float32Array` y) with a head index.
- **Conflation map:** `Map<key, latest>` merged each frame for tickers and grids.
- **rAF coalescer:** mark dirty on message and notify subscribers once in `requestAnimationFrame`.
- **Snapshot + delta:** fetch the snapshot (with `seq`), subscribe from `seq+1`, and drop deltas ≤ `seq`.
- **Visibility-aware connection:** close or throttle on hidden, reconnect and resnapshot on visible.
- **Worker ingestion:** the WebSocket lives in a SharedWorker/Worker, decodes binary, and posts batched Float32Arrays (transferable) to the UI.
- **"New items" pill** for logs when the user has scrolled up, instead of auto-scrolling.

## Anti-Patterns
- **`setState` per message** (for example, 200/s). Re-render storms and INP collapse. Fix: external store + frame coalescing.
- **`data = [...data, point]` forever.** Memory growth and O(n) copies. Fix: ring buffer / window.
- **Animated transitions on each update.** Constant layout/paint. Fix: animations off, canvas.
- **Tight reconnect loop without backoff.** Server thundering herd. Fix: exponential backoff + jitter, respect `retry`.
- **No stale indicator.** Users trust frozen numbers. Fix: last-updated timestamp + stale state.
- **SSE through a proxy with buffering** (nginx `proxy_buffering on`, compression). Events arrive in bursts. Fix: disable buffering for the route (`X-Accel-Buffering: no`) and avoid compressing the stream.
- **Auto-scrolling logs while the user reads.** Fix: pause on scroll-up, "Jump to latest".
- **`aria-live` on the whole live chart.** Fix: separate throttled summary, opt-in.
- **Long-lived WebSocket servers inside serverless route handlers.** Not supported or time-limited. Fix: a dedicated realtime server or managed service.

## Accessibility
- WCAG 2.2.2: auto-updating content needs a pause/stop control, and it should not auto-update when it's merely informational and distracting.
- Live regions: `role="status"` (polite) summary updated at most every 10–30s or on threshold crossings. Critical alerts use `role="alert"` sparingly.
- Don't move focus on updates. Keep the focused row/point stable when data shifts (key by id).
- Status indicator text ("Live", "Reconnecting…", "Paused") is not color-only.
- Reduced motion: no pulsing/flashing indicators. Nothing flashes more than 3 times per second (2.3.1).

## Responsive Design
- On mobile, lower the render rate and data window (fewer points), and pause when the app is backgrounded.
- Compact status indicator in the header, and live toggle reachable with the thumb.
- Consider switching from full charts to sparkline + value on small screens.

## Performance
- Target: main-thread work per frame under about 8ms. Parse/decode off the main thread for more than about 1k msg/s.
- Transfer `ArrayBuffer`s from workers (zero-copy) instead of cloning big arrays.
- Canvas charts: uPlot handles streaming thousands of points at 60fps with low CPU (per its benchmarks). Chart.js/ECharts are fine with windowed data and animations off.
- Virtualize live tables/logs (list-virtualization).
- Measure INP during bursts, since input responsiveness is the first casualty.

## Security
- Authenticate WebSocket upgrades (check `Origin`, use cookies with SameSite, or short-lived tokens in the first message, not long-lived tokens in URLs that end up in logs).
- Authorize subscriptions per topic/tenant on the server.
- Validate every inbound message with zod/valibot, and never `eval` or inject HTML from messages.
- Rate-limit client → server messages. Cap message size.
- CSP `connect-src` must list `wss://` and SSE origins explicitly.

## Testing
- **Unit:** ring buffer wraparound, conflation, backoff schedule (fake timers), seq/dedupe logic.
- **Integration:** mock WebSocket (`mock-socket`) or MSW's WebSocket support. Simulate disconnect → reconnect → resync.
- **E2E (Playwright):** route interception for SSE, `page.clock` for stale detection, offline toggling (`context.setOffline`).
- **Soak test:** 30–60 minutes with heap snapshots, and assert memory plateaus.
- **Burst test:** 10× message rate while typing in a filter, and check INP.

## Tooling
- Native `EventSource`, `WebSocket`; `WebSocketStream` (Chrome-only, experimental elsewhere).
- partysocket / reconnecting-websocket (auto-reconnect wrappers); socket.io (if the server uses it).
- Managed: Ably, Pusher, Supabase Realtime, Liveblocks, Convex (reactive queries).
- Charts: uPlot (streaming-optimized, ~50KB), Chart.js, ECharts.
- MessagePack (`@msgpack/msgpack`), Apache Arrow JS for columnar batches.

## Framework Notes
- **React (Vite SPA):**
  - Keep the connection in a module-level singleton or context provider, outside component lifecycles.
  - `useSyncExternalStore(store.subscribe, store.getSnapshot)`. Make snapshots immutable references that change only on flush.
  - StrictMode double-mount: make connect/disconnect idempotent (ref-count subscribers).
  - TanStack Query: push updates with `queryClient.setQueryData` for cached entities.
- **Next.js (App Router):**
  - Live components are `'use client'`. The initial snapshot is fetched in a Server Component and passed as props (no empty flash), then the client subscribes from `snapshot.seq`.
  - SSE from a Route Handler: return `new Response(ReadableStream)` with `Content-Type: text/event-stream`, `Cache-Control: no-cache, no-transform`, and `export const dynamic = 'force-dynamic'`. Honor `request.signal` to clean up.
  - Hosting duration limits apply on serverless platforms, so rely on client auto-reconnect + `Last-Event-ID`, or use a dedicated realtime service.
  - WebSockets aren't served by Route Handlers. Use a separate server or a managed provider.
  - Server Actions are not a streaming transport for live data.

## AI Agent Guidance
- DO choose the transport via the decision table and justify it.
- DO implement backoff with jitter, heartbeat, resume (seq/`Last-Event-ID`), and visibility handling.
- DO buffer outside React, coalesce renders per frame (or 1–2 Hz for numbers), and cap data windows.
- DO show connection and stale status plus a pause control.
- DON'T `setState` per message, grow arrays unbounded, animate live charts, or host WebSockets in Next.js route handlers.
- Before done: simulate disconnect/reconnect, background the tab, run a 10× burst while interacting (check INP), and confirm memory is stable over time.

## Examples
```ts
// lib/realtime/series-store.ts: bounded, frame-coalesced store
export function createSeriesStore(capacity = 3600) {
  const xs = new Float64Array(capacity), ys = new Float32Array(capacity);
  let head = 0, size = 0, dirty = false, version = 0;
  let snapshot = { version, xs: [] as number[], ys: [] as number[] };
  const listeners = new Set<() => void>();

  const flush = () => {
    dirty = false; version++;
    const outX = new Array(size), outY = new Array(size);
    for (let i = 0; i < size; i++) { const j = (head - size + i + capacity) % capacity; outX[i] = xs[j]; outY[i] = ys[j]; }
    snapshot = { version, xs: outX, ys: outY };
    listeners.forEach(l => l());
  };

  return {
    push(x: number, y: number) {
      xs[head] = x; ys[head] = y; head = (head + 1) % capacity; size = Math.min(size + 1, capacity);
      if (!dirty) { dirty = true; requestAnimationFrame(flush); }
    },
    subscribe(l: () => void) { listeners.add(l); return () => listeners.delete(l); },
    getSnapshot: () => snapshot,
  };
}
```
```ts
// lib/realtime/sse.ts: EventSource with status + visibility
import { z } from 'zod';
const Msg = z.object({ seq: z.number(), ts: z.number(), value: z.number() });
export type Status = 'connecting' | 'live' | 'reconnecting' | 'paused';

export function connectMetrics(url: string, onMsg: (m: z.infer<typeof Msg>) => void, onStatus: (s: Status) => void) {
  let es: EventSource | null = null;
  const open = () => {
    onStatus('connecting');
    es = new EventSource(url, { withCredentials: true });
    es.onopen = () => onStatus('live');
    es.onerror = () => onStatus('reconnecting'); // browser auto-reconnects, sends Last-Event-ID
    es.addEventListener('metric', e => {
      const parsed = Msg.safeParse(JSON.parse((e as MessageEvent).data));
      if (parsed.success) onMsg(parsed.data);
    });
  };
  const onVis = () => { if (document.hidden) { es?.close(); es = null; onStatus('paused'); } else if (!es) open(); };
  document.addEventListener('visibilitychange', onVis);
  open();
  return () => { document.removeEventListener('visibilitychange', onVis); es?.close(); };
}
```
```tsx
// components/LiveLatency.tsx
'use client';
import { useEffect, useMemo, useState, useSyncExternalStore } from 'react';
import { createSeriesStore } from '@/lib/realtime/series-store';
import { connectMetrics, type Status } from '@/lib/realtime/sse';

export function LiveLatency({ initial }: { initial: { ts: number; value: number }[] }) {
  const store = useMemo(() => { const s = createSeriesStore(1800); initial.forEach(p => s.push(p.ts, p.value)); return s; }, [initial]);
  const [status, setStatus] = useState<Status>('connecting');
  const [paused, setPaused] = useState(false);
  const snap = useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);

  useEffect(() => (paused ? undefined : connectMetrics('/api/metrics/stream', m => store.push(m.ts, m.value), setStatus)), [paused, store]);

  const last = snap.ys.at(-1);
  return (
    <section aria-labelledby="lat-h">
      <h2 id="lat-h">p95 latency</h2>
      <p role="status" aria-live="off">{paused ? 'Paused' : status === 'live' ? 'Live' : 'Reconnecting…'}</p>
      <button type="button" aria-pressed={paused} onClick={() => setPaused(p => !p)}>{paused ? 'Resume live' : 'Pause live'}</button>
      <p className="tabular-nums">{last !== undefined ? `${last.toFixed(0)} ms` : '—'}</p>
      {/* pass snap.xs / snap.ys to a canvas chart (uPlot/Chart.js) with animations off */}
    </section>
  );
}
```
```ts
// app/api/metrics/stream/route.ts: SSE Route Handler
export const dynamic = 'force-dynamic';
export async function GET(req: Request) {
  const enc = new TextEncoder();
  const lastId = Number(req.headers.get('last-event-id') ?? 0);
  const stream = new ReadableStream({
    start(controller) {
      let seq = lastId;
      const tick = setInterval(() => {
        seq++;
        const data = JSON.stringify({ seq, ts: Date.now(), value: 120 + Math.random() * 40 });
        controller.enqueue(enc.encode(`id: ${seq}\nevent: metric\ndata: ${data}\n\n`));
      }, 1000);
      const ping = setInterval(() => controller.enqueue(enc.encode(`: ping\n\n`)), 20000);
      controller.enqueue(enc.encode(`retry: 3000\n\n`));
      req.signal.addEventListener('abort', () => { clearInterval(tick); clearInterval(ping); controller.close(); });
    },
  });
  return new Response(stream, {
    headers: { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' },
  });
}
```
(Add authentication/authorization before exposing real data.)

## Related Skills
- [realtime-collaboration-ui](../realtime-collaboration-ui/Skill.md): presence/CRDT collaboration
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md)
- [dashboard-design](../dashboard-design/Skill.md): operational dashboards
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md)
- [inp-optimization](../inp-optimization/Skill.md): keeping input responsive under load
- [web-workers-offloading](../web-workers-offloading/Skill.md)
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md): SSE endpoints
- [list-virtualization](../list-virtualization/Skill.md): live logs/tables
- [content-security-policy](../content-security-policy/Skill.md): connect-src for wss/SSE

## Sources
- [MDN: Using server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events): Official; format, retry, Last-Event-ID, 6-connection limit
- [Chrome: WebSocketStream](https://developer.chrome.com/docs/capabilities/web-apis/websocketstream): Official; backpressure problem, Chrome-only status
- [uPlot](https://github.com/leeoniya/uPlot): Open Source; streaming performance benchmarks
- [React: useSyncExternalStore](https://react.dev/reference/react/useSyncExternalStore): Official; external store subscription (not re-fetched this cycle)

## License / Usage Notes
Code is original. MDN content is CC-BY-SA and summarized. Hosting duration limits vary by platform, so check your provider.

## Quality Tier
A: Official platform docs plus proven buffering patterns. Managed-service comparisons not verified in depth.

## Status
Active

## Last Verified
2026-09-15
