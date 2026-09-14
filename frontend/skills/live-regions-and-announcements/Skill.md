# Live Regions and Announcements

## Summary
Telling screen reader users about dynamic changes that don't move focus: status messages, toasts, form save confirmations, search result counts, loading and progress, chat messages, and errors. Covers ARIA live regions (`role="status"`, `role="alert"`, `role="log"`, `aria-live`, `aria-atomic`), the emerging `ariaNotify()` API, React-safe implementation (persistent regions, announcer hooks), and toast library behaviour.

## Category
Accessibility

## Subcategories
aria-live, role=status, role=alert, role=log, aria-atomic, aria-busy, ariaNotify, announcer, toasts, loading states, search results, chat streaming

## Problem It Solves
In React apps most feedback is visual and asynchronous: "Saved", "3 results", a spinner, a toast, streamed AI responses. Without announcements, screen reader users don't know an action succeeded, failed, or is still loading. Done wrong, live regions stay silent (region mounted with content), repeat endlessly, or interrupt users constantly. 4.1.3 Status Messages (AA) requires the right approach.

## When To Use
- Status messages that don't receive focus: "Item added to cart", "Draft saved", "24 results", "Copied", upload progress milestones.
- Errors after async actions when focus isn't moved (inline autosave failures).
- Chat and log UIs, and streamed AI responses.
- Client-side route change announcements (see accessible-spa-routing).

## When Not To Use
- When you move focus to the new content (dialogs, error summaries), since focus already announces it. Adding `role="alert"` too double-announces.
- For every keystroke or high-frequency update (live data tickers, typing counters). Throttle, or don't announce.
- For content the user must act on. Toasts that vanish can't hold required actions (2.2.1); use a dialog or persistent inline message.

## Core Principles
1. **The live region must exist in the DOM before its content changes.** Mount it empty, then update the text.
2. **Polite by default** (`role="status"` / `aria-live="polite"`). Use assertive (`role="alert"`) only for urgent, time-critical errors.
3. **Announce concise, meaningful text**: "Saved", not "The operation completed successfully at 10:42:13".
4. **Don't announce what focus already conveys.**
5. **Debounce and deduplicate.** One announcement per user-meaningful change.
6. **Visible and announced status should match** (4.1.3 targets visible status messages). Screen-reader-only announcements are fine as supplements.
7. **Test in real screen readers.** Live region support varies between NVDA, JAWS, VoiceOver and TalkBack.

## Best Practices
- Live region roles:
  | Role / attribute | Politeness | Atomic default | Use for |
  |---|---|---|---|
  | `role="status"` | polite | true | Save confirmations, result counts, non-urgent status |
  | `role="alert"` | assertive | true | Urgent errors ("Payment failed", "Connection lost") |
  | `role="log"` | polite | false | Chat, activity feeds (new entries appended) |
  | `role="timer"` / `marquee` | off | – | Rarely useful; avoid announcing timers |
  | `aria-live="polite"` on a div | polite | false | Custom regions; add `aria-atomic="true"` to read the whole region |
  | `<output>` | implicit status-like | – | Calculation results (support varies; add `role="status"`) |
- Keep one or two app-level announcer regions (polite and assertive) mounted in the root layout, and send messages to them.
- To re-announce identical text ("Copied" twice), clear the region then set the text on the next tick, or append a zero-width change.
- `aria-busy="true"` on a region while it updates in bulk, then `false`. Support is inconsistent, so also announce "Loading…" and "Loaded 20 results" politely.
- Loading spinners: visually hidden text "Loading" inside a `role="status"`. Don't announce every progress percentage; use milestones (25/50/75/100) or `<progress>` with a label.
- Toasts: render in a persistent polite region; errors can use assertive. Don't auto-dismiss toasts with actions; give them at least ~5–10s and pause on hover and focus. Provide a keyboard way to reach toast actions (e.g., F6 or a landmark).
- Streaming AI responses: don't live-announce each token. Announce "Response ready" (or the final message) when streaming completes, and let users read the message in a `role="log"` list.
- `ariaNotify(message, { priority })` (Element/Document method): announces without DOM changes. Limited availability (not Baseline) as of Sept 2026, so feature-detect and fall back to live regions.

## Implementation Guidance

### App-level announcer (React context)
```tsx
'use client';
import { createContext, useCallback, useContext, useRef, useState } from 'react';

type Politeness = 'polite' | 'assertive';
const AnnouncerContext = createContext<(msg: string, p?: Politeness) => void>(() => {});

export function AnnouncerProvider({ children }: { children: React.ReactNode }) {
  const [polite, setPolite] = useState('');
  const [assertive, setAssertive] = useState('');
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const announce = useCallback((msg: string, p: Politeness = 'polite') => {
    const el = document.documentElement as Element & { ariaNotify?: (m: string, o?: { priority?: 'normal' | 'high' }) => void };
    if (typeof el.ariaNotify === 'function') { el.ariaNotify(msg, { priority: p === 'assertive' ? 'high' : 'normal' }); return; }
    const set = p === 'assertive' ? setAssertive : setPolite;
    set('');                                   // clear so repeated messages re-announce
    clearTimeout(timer.current);
    timer.current = setTimeout(() => set(msg), 100);
  }, []);

  return (
    <AnnouncerContext.Provider value={announce}>
      {children}
      <div role="status" aria-live="polite" aria-atomic="true" className="sr-only">{polite}</div>
      <div role="alert" aria-live="assertive" aria-atomic="true" className="sr-only">{assertive}</div>
    </AnnouncerContext.Provider>
  );
}
export const useAnnounce = () => useContext(AnnouncerContext);
```
Usage: `const announce = useAnnounce(); await save(); announce('Draft saved');`.

Choose one path per message (ariaNotify or region) to avoid double announcements. Since `ariaNotify` support is still settling, some teams keep live regions only until it reaches Baseline.

### React Aria announcer
```ts
import { announce } from '@react-aria/live-announcer';
announce('24 results', 'polite');
```
It manages its own hidden live regions, handles re-announcement, and is used internally by React Aria components.

### Search result count (debounced)
```tsx
function ResultsCount({ count, loading }: { count: number; loading: boolean }) {
  const [msg, setMsg] = useState('');
  useEffect(() => {
    const t = setTimeout(() => setMsg(loading ? 'Loading results' : `${count} ${count === 1 ? 'result' : 'results'}`), 500);
    return () => clearTimeout(t);
  }, [count, loading]);
  return <p role="status" aria-atomic="true">{msg}</p>; // visible and announced
}
```

### Chat log
```tsx
<ol role="log" aria-label="Conversation" aria-relevant="additions">
  {messages.map(m => <li key={m.id}><strong>{m.author}:</strong> {m.done ? m.text : 'Typing…'}</li>)}
</ol>
```
Use `aria-busy={streaming}` on the in-progress message and a separate polite announcement "Assistant replied" on completion. Test carefully: log regions with streaming updates can over-announce.

### Toast libraries
- **Sonner** renders an `<ol>` inside a labelled `section` region ("Notifications alt+T") with `aria-live="polite"`. Verify that error toasts are announced and actions are reachable.
- **Radix Toast** uses a viewport region with hotkey F8, `type="foreground"` (assertive) vs `"background"` (polite), and pauses on hover and focus.
- **React Aria Toast** (`UNSTABLE_ToastRegion`/`ToastQueue`) implements a landmark with F6 navigation. Check the API stability of your version.

## Recommended Workflow
1. List dynamic changes per feature and decide for each: move focus, announce politely, announce assertively, or nothing.
2. Mount the announcer provider in the root layout (once).
3. Write concise message copy (with content design), including success, error and loading text.
4. Implement with debouncing and deduplication.
5. Test with NVDA+Chrome, JAWS+Chrome and VoiceOver+Safari: each message spoken once, at the right time, without cutting off other speech unnecessarily.
6. Add component tests asserting the status region's text.

## Patterns
- **Visible status plus region.** An inline "Saved ✓" text inside `role="status"` next to the form.
- **Clear-then-set** for repeated messages.
- **Milestone progress.** "Upload 50% complete" at quarter steps; "Upload complete" at the end.
- **Batch updates.** "3 items added" instead of three separate announcements.
- **Offline banner.** `role="alert"` once when the connection drops; `role="status"` "Back online" when restored.

## Anti-Patterns
- **Conditionally rendering `{saved && <div role="status">Saved</div>}`.** The region and its content mount together, which many screen readers ignore. Keep the region mounted.
- **`aria-live="assertive"` for everything.** Interrupts users mid-sentence. Default to polite.
- **Live region around a large container** (entire results list). Reads everything on every change. Announce a summary.
- **Announcing on every keystroke** (character counters, typeahead counts). Debounce 500ms+.
- **`role="alert"` plus moving focus to the same element.** Double announcement. Pick one.
- **Auto-dismissing toasts with "Undo"** in 3 seconds. Fails 2.2.1 for many users. Extend it, pause on hover and focus, or make it persistent.
- **Using live regions to announce page navigation instead of managing focus and title.** Incomplete. See accessible-spa-routing.
- **`display: none` or `hidden` live regions.** Hidden regions aren't announced. Use `sr-only` visually hidden styling.

## Accessibility
- 4.1.3 Status Messages (AA), 3.3.1 Error Identification (A, for async errors), 2.2.1 Timing Adjustable (A, for toasts), 1.3.1, 4.1.2.
- ARIA: `aria-live`, `aria-atomic`, `aria-relevant` (limited support; stick to defaults), `aria-busy`.

## Responsive Design
- Mobile screen readers (VoiceOver iOS, TalkBack) support polite regions, but may drop rapid successive messages. Batch them.
- Toast placement differs on mobile; ensure toasts don't cover focused inputs or the on-screen keyboard (2.4.11).

## Performance
- Announcer state updates re-render only the provider's regions. Isolate the provider so it doesn't re-render the app tree (keep the message state in a small child component, or use refs with direct `textContent` updates).

## Security
- Don't announce sensitive data (full card numbers, one-time codes) in live regions. Nearby people can hear them.
- Escape server messages before announcing them (JSX does).

## Testing
```tsx
test('announces saved status', async () => {
  const user = userEvent.setup();
  render(<AnnouncerProvider><EditorToolbar /></AnnouncerProvider>);
  await user.click(screen.getByRole('button', { name: /save draft/i }));
  expect(await screen.findByRole('status')).toHaveTextContent('Draft saved');
});
```
- Playwright: `await expect(page.getByRole('status')).toHaveText('24 results')`.
- Manual: NVDA Speech Viewer and VoiceOver Caption Panel to confirm each message is spoken exactly once. Test rapid repeated actions.
- Guidepup (experimental) can capture spoken output in CI for critical flows.

## Tooling
- `@react-aria/live-announcer`, Radix Toast, Sonner, React Aria Toast.
- Browser `ariaNotify()` (limited availability; feature-detect).
- NVDA Speech Viewer, VoiceOver Caption Panel, JAWS Speech History.
- axe rules: `aria-allowed-role`, `aria-valid-attr-value` (axe can't verify announcements).

## Framework Notes
- **Next.js.**
  - Place `AnnouncerProvider` in `app/layout.tsx` (client component wrapper).
  - After Server Actions, announce from the client in `useActionState` effects or transitions.
  - `loading.tsx` renders on navigation: include `role="status"` with "Loading…" text in the fallback UI.
  - Next.js's built-in route announcer is a separate live region for navigation. Don't duplicate route messages.
- **React (Vite SPA).** Same provider in the app root. Suspense fallbacks should contain a polite status. Route announcements need your own implementation.
- **React 19 transitions.** `useTransition`'s `isPending` can drive "Saving…" and "Saved" messages. Avoid announcing "Saving…" for sub-300ms operations.

## AI Agent Guidance
- Do: route all non-focus status messages through a single persistent announcer; debounce counts; use polite by default; make toasts pause and persist when actionable.
- Do: write concise message copy and include it in tests.
- Don't: conditionally mount live regions with content, use assertive for non-urgent messages, announce streaming tokens, or announce sensitive data.
- Verify before done:
  - `getByRole('status')` has the expected text
  - no double announcements with focus moves
  - manual NVDA or VoiceOver confirmation noted, or flagged as pending

## Examples
See Implementation Guidance (announcer provider, result counts, chat log).

## Related Skills
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — toast component design
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — navigation announcements
- [loading-states](../loading-states/Skill.md) — loading UX
- [focus-management](../focus-management/Skill.md) — focus vs announce decision
- [ai-chat-interface-ux](../ai-chat-interface-ux/Skill.md) — streaming responses
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — result count announcements
- [screen-reader-testing](../screen-reader-testing/Skill.md) — verifying announcements

## Sources
- [WAI-ARIA 1.2: Live Region attributes and roles](https://www.w3.org/TR/wai-aria-1.2/#live_region_roles) — Official — role semantics and defaults
- [Understanding 4.1.3 Status Messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html) — Official — requirement scope
- [MDN: Element.ariaNotify()](https://developer.mozilla.org/en-US/docs/Web/API/Element/ariaNotify) — Official (MDN) — API, priority, limited availability
- [MDN: ARIA live regions](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions) — Official (MDN) — implementation guidance
- [React Aria live announcer](https://react-spectrum.adobe.com/react-aria/) — Open Source — announce API
- [Scott O'Hara / Sara Soueidan on live regions & toasts](https://www.scottohara.me/) — Community — AT behaviour quirks
- [Radix Toast](https://www.radix-ui.com/primitives/docs/components/toast) — Open Source — foreground/background politeness

## License / Usage Notes
Summarised from W3C, MDN and library docs. Code is original.

## Quality Tier
A — standards-accurate with robust React patterns. `ariaNotify` and toast library behaviours are still evolving and need re-checking.

## Status
Active

## Last Verified
2026-09-15
