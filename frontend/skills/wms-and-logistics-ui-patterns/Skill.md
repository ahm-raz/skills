# WMS and Logistics UI Patterns

## Summary
UI patterns for warehouse management and logistics apps in React + Next.js: scan-first task flows on rugged handhelds (receiving, putaway, picking, packing, cycle counts), shipment tracking timelines, dock/yard scheduling, and exception handling. Floor apps have to work with gloves, glare, noise, flaky Wi-Fi, and hardware barcode scanners that act as keyboards. Control-room apps need dense, live-updating overviews.

## Category
Enterprise UI

## Subcategories
Barcode scanning, task-directed work, handheld/rugged device UX, offline queues, shipment tracking, dock scheduling, exception management, labels and printing

## Problem It Solves
Desktop-style forms fail on the warehouse floor. Tiny targets, focus that drifts away from the scan field, silent errors, and lost scans during Wi-Fi drops all cause mis-picks, re-work, and inventory inaccuracy. Logistics dashboards fail differently: they bury exceptions under normal shipments. This skill gives concrete floor-UX and exception-first patterns.

## When To Use
- Handheld or wearable apps for warehouse operators (Android enterprise devices with built-in scanners, ring scanners paired as HID keyboards).
- Station apps (packing bench, receiving dock) with USB/Bluetooth scanners and label printers.
- Supervisor and control-tower views: waves, dock schedule, carrier ETAs, exceptions.
- Last-mile or yard apps that track stops, proofs of delivery, and trailer moves.

## When Not To Use
- Office back-office screens for inventory valuation or procurement. See `erp-ui-patterns`.
- Consumer order tracking pages (simpler, marketing-driven). Use `ecommerce-ux-patterns`.
- Native-only hardware integrations (RFID SDKs, device-specific scanner intents) that a web app cannot reach. Evaluate a native wrapper instead.

## Core Principles
1. **Scan first, type last.** The default input is the scanner. Manual entry is the fallback, and it's logged.
2. **One task, one screen, one next step.** Task-directed flows tell the operator exactly where to go and what to scan.
3. **Loud, unambiguous feedback.** Success and error differ in color, icon, text, sound, and vibration. Errors require acknowledgement.
4. **Never lose a scan.** Queue mutations locally when offline, with idempotency keys, and reconcile visibly.
5. **The server validates every scan** (location, item, lot/serial, quantity, task ownership). The client only pre-checks for speed.
6. **Exceptions over averages.** Supervisor views lead with what's late, short, damaged, or blocked.

## Best Practices
- **Scan field focus**: keep a single scan input focused whenever no dialog is open. Re-focus after each submit, after dialogs close, and on `visibilitychange`. Never steal focus while the user is typing in another field.
- **Wedge scanners** send characters quickly, usually followed by Enter (sometimes Tab). Configure the device suffix to Enter. Detect scans on Enter and trim prefixes/suffixes. Optionally distinguish human typing by inter-key timing, but don't rely on it for security.
- **Parse GS1** barcodes (Application Identifiers for GTIN, lot, expiry, serial, SSCC) on the server or in a shared, tested parser. Show the parsed fields back to the user.
- **Verify step by step**: "Go to A-12-03" -> scan location -> "Pick 4 × SKU 12345" -> scan item (or quantity entry) -> confirm. Show progress ("Line 3 of 12").
- **Targets**: at least 48×48 CSS px for primary actions on handhelds, with generous spacing. WCAG 2.2 minimum is 24×24, but gloves need far more. Put primary action buttons in the thumb zone at the bottom.
- **Contrast & glare**: high-contrast theme (well beyond 4.5:1), large type (≥18px body on handhelds), no thin fonts, avoid pure-color-only status.
- **Feedback**: success = short beep + brief green banner. Error = distinct tone + `navigator.vibrate` where supported + red full-width banner that requires a tap or scan to dismiss. Browser audio needs a prior user gesture; prime it at shift start.
- **Short picks & exceptions**: always offer "Short", "Damaged", "Location empty", "Wrong item" with required reason codes. They route to a supervisor exception queue.
- **Sessions**: shared devices need fast user switching (badge scan login), auto-lock on idle, and task release on logout.
- **Shipment timeline**: milestones (created, picked up, departed facility, in transit, out for delivery, delivered/exception) with planned vs actual times, the event source (carrier/EDI/scan), and the time zone of each location.
- **Dock scheduling**: a resource-by-time grid (docks × hours) with appointment blocks, status colors plus labels, a drag-to-reschedule alternative via form, and conflict validation on the server.

## Implementation Guidance

### Scan input hook
```tsx
'use client';
import { useCallback, useEffect, useRef } from 'react';

export function useScanInput(onScan: (code: string) => void, { enabled = true } = {}) {
  const ref = useRef<HTMLInputElement>(null);
  const refocus = useCallback(() => {
    if (!enabled) return;
    const active = document.activeElement;
    const typingElsewhere = active instanceof HTMLInputElement && active !== ref.current;
    if (!typingElsewhere && !document.querySelector('dialog[open]')) ref.current?.focus();
  }, [enabled]);

  useEffect(() => {
    refocus();
    const onVis = () => document.visibilityState === 'visible' && refocus();
    document.addEventListener('visibilitychange', onVis);
    return () => document.removeEventListener('visibilitychange', onVis);
  }, [refocus]);

  const inputProps = {
    ref,
    inputMode: 'none' as const, // suppress soft keyboard on handhelds; offer a "Type code" button to switch to text
    autoComplete: 'off',
    autoCorrect: 'off',
    spellCheck: false,
    onKeyDown: (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter' || e.key === 'Tab') {
        e.preventDefault();
        const code = e.currentTarget.value.trim();
        e.currentTarget.value = '';
        if (code) onScan(code);
        requestAnimationFrame(refocus);
      }
    },
    onBlur: () => setTimeout(refocus, 150),
  };
  return { inputProps, refocus };
}
```
`inputMode="none"` behavior varies by device and browser. Test on the target hardware and give an explicit "Type code" toggle.

### Pick task Server Action (server validates, idempotent)
```ts
'use server';
import { z } from 'zod';
import { confirmPickScan } from '@/data/picking';

const Scan = z.object({
  taskId: z.string().uuid(),
  step: z.enum(['location', 'item', 'quantity']),
  code: z.string().min(1).max(200),
  quantity: z.coerce.number().int().positive().optional(),
  idempotencyKey: z.string().uuid(),
  scannedAt: z.string().datetime(), // device time, stored alongside server time
});

export type ScanResult =
  | { ok: true; next: { step: 'location' | 'item' | 'quantity' | 'done'; prompt: string } }
  | { ok: false; code: 'WRONG_LOCATION' | 'WRONG_ITEM' | 'LOT_EXPIRED' | 'TASK_REASSIGNED' | 'INVALID'; message: string };

export async function scanAction(raw: unknown): Promise<ScanResult> {
  const p = Scan.safeParse(raw);
  if (!p.success) return { ok: false, code: 'INVALID', message: 'Unreadable scan' };
  return confirmPickScan(p.data); // session, task assigned to this operator, location/item/lot match, stock update, dedupe by key
}
```

### Offline queue (floor devices)
| Concern | Approach |
|---|---|
| Storage | IndexedDB queue of `{ idempotencyKey, action, payload, createdAt, attempts }` |
| Sending | FIFO, one at a time. Retry with backoff when `navigator.onLine` / fetch succeeds |
| UI | Persistent badge "3 scans pending sync". Block end-of-task/close-wave until the queue is empty |
| Conflicts | Server returns per-item results. Rejected items go to "Needs attention" with the reason |
| Scope | Offline allowed only for pre-validated steps (e.g., counts). Never for actions needing live stock checks, such as allocation. Decide per process with operations |

Server Actions need connectivity. For queued replays, use a Route Handler (`app/api/scans/route.ts`) that accepts batches and applies the same DAL, or call the action when back online.

## Recommended Workflow
1. Shadow operators on the floor. Record devices, scanner suffix config, gloves, lighting, and connectivity dead zones.
2. Map each process (receive, putaway, pick, pack, ship, count) into steps with expected scans and exception codes.
3. Define the scan validation contract and GS1 parsing on the server. Write fixture tests with real label samples.
4. Build a shared `TaskScreen` shell: header (task, progress), instruction block, scan field, feedback banner, bottom actions.
5. Implement feedback (sound, vibration, banner) and a focus-management hook.
6. Add the offline queue and sync UI where operations allow.
7. Build the supervisor views: exception queue, wave progress, dock schedule, shipment timelines.
8. Pilot on real hardware in the real environment. Measure scans per minute and error rate. Iterate.

## Patterns
- **Instruction block**: huge location code (e.g., `A-12-03` at 40px+), item description, quantity with unit, image thumbnail if available.
- **Confirm by scan, not tap**: moving on requires scanning the expected barcode. Manual override requires a reason and is audited.
- **Exception sheet**: a bottom sheet with 4–6 large reason buttons. Selecting one creates an exception and moves to the next task.
- **Pending-sync badge**: always visible in the header when the queue is non-empty.
- **Control tower list**: default sort by risk (late + high priority first) with an exception count per shipment and filter chips (Late, At risk, Damaged, Customs hold).
- **Milestone timeline**: vertical on mobile, horizontal on desktop. Planned (hollow) vs actual (filled) markers with labels.

## Anti-Patterns
- **Scan field loses focus after a dialog or toast.** Scans go nowhere or into the wrong field. Fix: centralized refocus after every state change and dialog close.
- **Success/error only by color.** Glare and color vision deficiency hide it. Fix: icon + text + sound + vibration.
- **Auto-dismissing error toasts.** The operator looks at the shelf, not the screen. Fix: blocking error banner acknowledged by tap or scan.
- **Client-side stock validation as truth.** Double allocation across devices. Fix: server validates atomically.
- **Silently dropping scans offline.** Inventory drift. Fix: idempotent queue, visible pending count, reconciliation screen.
- **Desktop-density tables on handhelds.** Fix: one-task screens with large type and targets.
- **Showing carrier times in the viewer's time zone without a label.** Fix: show the local time of the event location with a zone abbreviation, and the absolute timestamp on demand.

## Accessibility
- Target size: meet WCAG 2.2 SC 2.5.8 (24×24 minimum) but design for ≥48px on floor devices.
- Status messages (scan accepted/rejected) use `role="status"` / `role="alert"` (SC 4.1.3). Don't depend only on audio (SC 1.1.1 alternatives for sound cues).
- Non-color cues (SC 1.4.1). High contrast (SC 1.4.3/1.4.11). Honor `prefers-reduced-motion` for flashing banners, and never flash more than 3 times per second (SC 2.3.1).
- Focus visible (SC 2.4.7) even with the scan field auto-focus. Keep a logical order for manual input mode.
- Dock schedule grid: provide a list/table alternative with a keyboard-accessible "Reschedule" form rather than drag only (SC 2.5.7).

## Responsive Design
- Handheld (roughly 360–480px wide): single column, bottom action bar, no hover-dependent UI, portrait lock expectations.
- Station (tablet/desktop): split view with task on the left and packing contents / label preview on the right.
- Control tower (large monitors / TV walls): larger type, auto-refresh, no hover, high-contrast theme, and a kiosk-safe logout.
- Test with device-size emulation and on real rugged devices. Emulation doesn't reproduce scanners or glare.

## Performance
- Target sub-100ms feedback after a scan. Show local "received" feedback immediately, then the server verdict. Keep the round-trip small (tiny payloads, no full page revalidation).
- Avoid heavy client bundles on low-end Android devices. Code-split supervisor features away from operator routes.
- Pre-fetch the next task while confirming the current one.
- Live control-tower views use SSE/WebSocket with throttled rendering (see `realtime-data-ui`), or polling at a sensible interval.

## Security
- Authenticate operators individually (badge scan + PIN) even on shared devices. Auto-lock on idle.
- Every scan mutation is authorized server-side: task assigned to this operator, same site/warehouse tenant.
- Treat barcode content as untrusted input: validate length and charset, never render it as HTML, and never use it directly in queries.
- Idempotency keys prevent replayed or duplicated queue submissions. Log manual overrides with the reason and user.
- Kiosk/control-tower screens show only the data needed. Avoid exposing customer PII on public-facing monitors.

## Testing
- Unit: GS1/barcode parser with real label fixtures, scan-step reducer, offline queue ordering and retry.
- Component: `useScanInput` with simulated rapid keydown sequences ending in Enter. Refocus after dialog close.
- E2E (Playwright): full pick task via `page.keyboard.type(code + '\n')`, wrong-location scan shows a blocking error, offline mode (`context.setOffline(true)`) queues scans and syncs on reconnect.
- Field testing: real devices, gloves, sunlight, Wi-Fi dead zones. Measure task time and error rate.

## Tooling
- Hardware scanners configured as HID keyboard wedge with an Enter suffix (device vendor tools).
- Camera scanning fallback: the `BarcodeDetector` Web API is not supported in all browsers, so check current support. Libraries such as ZXing-based packages exist; check maintenance status.
- IndexedDB wrappers (e.g., `idb`) for offline queues. Service workers for app-shell caching (see `service-workers-and-offline`).
- `navigator.vibrate` (not supported on iOS Safari) and the Web Audio API for feedback.
- Label printing: usually via server-generated ZPL/PDF sent to print services. Browser printing is only for low-volume desks.
- dnd-kit or a scheduling component for dock boards (see `resource-scheduling-and-timeline-views`).

## Framework Notes
- **Next.js (App Router, 16)**: operator task routes are thin Client Components inside a minimal layout (no heavy nav). Scan validation uses Server Actions or a batched Route Handler for offline replay. Supervisor views are Server Components with streaming. `proxy.ts` can route unauthenticated devices to badge login, but authorization stays in the DAL. Consider PWA installation for kiosk-like launching.
- **React (Vite SPA)**: often the better fit for offline-heavy handheld apps. Service worker + IndexedDB + API with idempotency headers. Smaller runtime on low-end devices. TanStack Query's `networkMode` and persisted mutations can help, so check current docs.

## AI Agent Guidance
- Do: build a single scan input with robust refocus and Enter-terminated detection. Test with simulated rapid keystrokes.
- Do: give every result multi-channel feedback, and block on errors.
- Do: add idempotency keys to every scan mutation, and a visible offline queue where offline is allowed.
- Don't: validate stock or location on the client only; don't use small desktop controls on handheld routes.
- Don't: assume camera `BarcodeDetector` or vibration is available everywhere.
- Verify before done: a keyboard-simulated scan completes a task end to end; focus returns to the scan field after every dialog; offline scans sync exactly once; error states are visible without color or sound.

## Examples
```tsx
'use client';
import { useState } from 'react';
import { scanAction, type ScanResult } from './actions';
import { useScanInput } from './use-scan-input';

export function PickStep({ taskId, prompt }: { taskId: string; prompt: string }) {
  const [feedback, setFeedback] = useState<ScanResult | null>(null);
  const [current, setCurrent] = useState(prompt);
  const { inputProps } = useScanInput(async (code) => {
    const r = await scanAction({ taskId, step: 'location', code, idempotencyKey: crypto.randomUUID(), scannedAt: new Date().toISOString() });
    setFeedback(r);
    if (r.ok) { setCurrent(r.next.prompt); navigator.vibrate?.(40); }
    else navigator.vibrate?.([120, 60, 120]);
  });

  return (
    <main className="flex min-h-dvh flex-col gap-4 p-4 text-lg">
      <p className="text-4xl font-bold tracking-wide">{current}</p>
      <label className="sr-only" htmlFor="scan">Scan barcode</label>
      <input id="scan" {...inputProps} className="h-14 rounded border-2 px-3 text-xl" />
      {feedback && !feedback.ok && (
        <div role="alert" className="rounded bg-red-700 p-4 text-white">
          <strong>✖ {feedback.message}</strong>
          <button className="mt-3 h-14 w-full rounded bg-white text-red-800" onClick={() => setFeedback(null)}>OK</button>
        </div>
      )}
      {feedback?.ok && <p role="status" className="rounded bg-green-700 p-3 text-white">✔ Accepted</p>}
      <nav className="mt-auto grid grid-cols-2 gap-3">
        <button className="h-14 rounded border-2">Short / Exception</button>
        <button className="h-14 rounded border-2">Type code</button>
      </nav>
    </main>
  );
}
```

## Related Skills
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — target sizes and gestures
- [service-workers-and-offline](../service-workers-and-offline/Skill.md) — offline app shell and queues
- [progressive-web-apps](../progressive-web-apps/Skill.md) — installable floor apps
- [realtime-data-ui](../realtime-data-ui/Skill.md) — live control-tower views
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — scan result announcements
- [focus-management](../focus-management/Skill.md) — scan field focus handling
- [resource-scheduling-and-timeline-views](../resource-scheduling-and-timeline-views/Skill.md) — dock scheduling boards
- [workflow-and-approval-ui](../workflow-and-approval-ui/Skill.md) — exception resolution flows
- [erp-ui-patterns](../erp-ui-patterns/Skill.md) — back-office inventory screens
- [mobile-web-app-patterns](../mobile-web-app-patterns/Skill.md) — handheld layout conventions

## Sources
- [Next.js data security guide](https://nextjs.org/docs/app/guides/data-security) — Official — server-side authorization in actions, input validation
- [NN/g complex applications](https://www.nngroup.com/articles/complex-application-design/) — Official (research) — salient information, efficient methods for trained users
- [WAI-ARIA APG Grid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) — Official — keyboard model for schedule grids
- [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — target size, status messages, dragging movements (criteria referenced from general knowledge; confirm wording)

## License / Usage Notes
Original, summarized guidance. GS1 standards have their own usage terms; consult GS1 General Specifications for AI definitions. Hardware vendor SDKs have separate licenses.

## Quality Tier
C — practical and security-sound, but WMS floor-UX guidance is mostly practitioner knowledge; no WMS-specific official design source was verified in this pass, and device API support must be rechecked.

## Status
Active

## Last Verified
2026-09-15
