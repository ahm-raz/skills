# Micro-interactions

## Summary
Micro-interactions are small, single-purpose moments of feedback: a button press, a toggle flip, a copy-to-clipboard confirmation, a like burst, input validation, a hover reveal. Done well, they make a React/Next.js interface feel responsive and trustworthy. Done badly, they add latency and noise. This skill turns Dan Saffer's trigger→rules→feedback→loops model and design-engineering practice (Emil Kowalski's rules, Material/Apple guidance) into concrete TSX + CSS patterns with timing tables.

## Category
Animation

## Subcategories
Press feedback, hover states, toggles, copy confirmation, loading buttons, form validation feedback, tooltips, number/tick animations, haptic-like cues

## Problem It Solves
Interfaces without feedback feel broken ("did my click register?"), and interfaces with over-animated feedback feel slow. Teams need defaults for what to animate, how fast, and when to skip animation entirely, so every button, toggle, and menu behaves consistently.

## When To Use
- Every interactive control in a design system (buttons, switches, checkboxes, tabs).
- Async actions: submit, save, copy, add to cart. Acknowledge instantly, resolve visibly.
- State confirmation for low-visibility changes (copied, saved, liked).
- Hover/focus affordances on pointer devices.

## When Not To Use
- Keyboard-driven, high-frequency actions (command palette navigation, list arrow-keying). Skip animation.
- Actions users do hundreds of times a day. Remove or minimize the motion.
- Purely decorative flourishes with no information value on core workflows.
- When the response is instant and the state change is already obvious (e.g. text input characters).

## Core Principles
1. Feedback within 100ms of input. The press state must be immediate, even if the result is async.
2. Every micro-interaction answers one question: did it register, what changed, or what can I do.
3. Faster is better: 100–200ms for most feedback. Exits are faster than entries.
4. Ease-out for responses; never ease-in for feedback.
5. Frequency lowers the animation budget. The more often it's seen, the subtler it should be.
6. Motion is never the only signal. Pair it with text, icon, ARIA, or color and shape changes.
7. Interruptible: rapid repeated input must not queue animations.

## Best Practices
- Press: `scale: 0.97` on `:active` over 100–150ms, with the release returning over ~150ms.
- Hover: color/background changes at 150ms `ease`, gated behind `@media (hover: hover) and (pointer: fine)`.
- Toggles: thumb translate 150–200ms with a spring-like `linear()` or `cubic-bezier(0.23,1,0.32,1)`.
- Tooltips: ~300–500ms open delay on first hover, then instant (no delay, no animation) for subsequent tooltips while the user is scanning.
- Copy/confirm: swap icon with a 150ms crossfade/scale (0.8→1), hold 1.5–2s, revert, and announce via a live region.
- Loading buttons: keep width stable (overlay the spinner), disable re-submit, and show the spinner only after ~300ms to avoid flashes on fast responses.
- Hold-to-confirm destructive actions: slow and linear while holding (1–2s), snappy (200ms ease-out) on release.
- Set `transform-origin` toward the trigger for menus and popovers (Radix: `var(--radix-popover-content-transform-origin)`).
- Use CSS transitions (retargetable) rather than keyframes for anything that can be toggled rapidly.

## Implementation Guidance

### Timing table
| Micro-interaction | Duration | Easing | Notes |
|---|---|---|---|
| Button press | 100–150ms | ease-out | `scale: 0.97` |
| Hover color | 150ms | ease | Pointer devices only |
| Focus ring appear | 0–100ms | — | Never delay focus visibility |
| Switch thumb | 150–200ms | `cubic-bezier(0.23,1,0.32,1)` | Also change color + aria-checked |
| Checkbox check draw | 150–250ms | ease-out | SVG `stroke-dashoffset` |
| Tooltip open | 125–200ms (after delay) | ease-out | Subsequent tooltips instant |
| Dropdown open / close | 150–200ms / 100–150ms | ease-out | Origin-aware scale 0.96→1 |
| Copy confirmation | 150ms swap, hold 1500–2000ms | ease-out | Live region "Copied" |
| Toast enter / exit | 300ms / 200ms | ease-out / ease-in-out | Stack with transitions |
| Number tick/count | 300–600ms | ease-out | Tabular numerals |
| Shake on error | 300–400ms, ≤3 cycles | ease-in-out | Plus text error; reduced motion: none |
| Like/celebration burst | 400–700ms | spring | Low frequency only |

### Should this animate? (frequency budget)
| Frequency | Examples | Motion budget |
|---|---|---|
| 100+/day, keyboard | Palette navigation, shortcuts | None |
| Dozens/day | Sidebar toggles, tab switches | Minimal (≤150ms opacity/position) |
| Occasional | Modal open, save, copy | Standard (150–300ms) |
| Rare/first-time | Onboarding complete, purchase | Expressive (≤700ms, spring, celebration) |

### CSS vs Motion vs other
| Need | Tool |
|---|---|
| Press, hover, focus, toggle | CSS transitions |
| Icon swap with exit | CSS (both icons in DOM, crossfade) or Motion `AnimatePresence mode="popLayout"` |
| Spring with velocity (drag switch) | Motion for React |
| Complex celebratory vector animation | Lottie/Rive |
| Number rolling | CSS `@property` counter or a small NumberFlow-style component |

## Recommended Workflow
1. Inventory interactive components and classify each by frequency (table above).
2. Define motion tokens (`--dur-press`, `--ease-out`) in the design system.
3. Implement CSS-first interactions on primitives (Button, Switch, Checkbox, Tooltip).
4. Add non-motion signals: ARIA state, text, and live regions.
5. Add reduced-motion variants (keep color/opacity, drop scale/translate/shake).
6. Test rapid clicking, keyboard activation (Space/Enter trigger `:active` differently), and touch.
7. Record at 0.25x speed and review for jumps, double animations, and layout shift.

## Patterns

### Button with press feedback and async state
```tsx
"use client";
import { useState } from "react";

export function SaveButton({ onSave }: { onSave: () => Promise<void> }) {
  const [state, setState] = useState<"idle" | "saving" | "saved">("idle");
  async function handle() {
    if (state === "saving") return;
    setState("saving");
    try { await onSave(); setState("saved"); setTimeout(() => setState("idle"), 1800); }
    catch { setState("idle"); }
  }
  return (
    <button className="btn" data-state={state} aria-busy={state === "saving"} onClick={handle}>
      <span className="btn-label">{state === "saved" ? "Saved" : "Save"}</span>
      <span className="btn-spinner" aria-hidden />
      <span role="status" className="sr-only">{state === "saved" ? "Changes saved" : ""}</span>
    </button>
  );
}
```
```css
.btn { position: relative; transition: scale 120ms var(--ease-out), background-color 150ms ease; }
.btn:active:not([aria-busy="true"]) { scale: 0.97; }
.btn-spinner { position: absolute; inset: 0; margin: auto; inline-size: 1rem; block-size: 1rem; opacity: 0; transition: opacity 150ms; }
.btn[data-state="saving"] .btn-label { opacity: 0; }
.btn[data-state="saving"] .btn-spinner { opacity: 1; transition-delay: 300ms; } /* avoid flash on fast saves */
@media (hover: hover) and (pointer: fine) { .btn:hover { background-color: var(--btn-hover); } }
@media (prefers-reduced-motion: reduce) { .btn:active { scale: 1; } }
```

### Copy button with icon crossfade
```tsx
"use client";
import { useState } from "react";
import { Check, Copy } from "lucide-react";

export function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="copy"
      data-copied={copied}
      aria-label={copied ? "Copied" : "Copy to clipboard"}
      onClick={async () => {
        await navigator.clipboard.writeText(value);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
      }}
    >
      <Copy className="icon icon-copy" aria-hidden />
      <Check className="icon icon-check" aria-hidden />
      <span role="status" className="sr-only">{copied ? "Copied" : ""}</span>
    </button>
  );
}
```
```css
.copy { display: grid; }
.copy .icon { grid-area: 1 / 1; transition: opacity 150ms var(--ease-out), scale 150ms var(--ease-out); }
.copy .icon-check { opacity: 0; scale: 0.8; }
.copy[data-copied="true"] .icon-copy { opacity: 0; scale: 0.8; }
.copy[data-copied="true"] .icon-check { opacity: 1; scale: 1; }
```

### Switch
```tsx
export function Switch({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <button role="switch" aria-checked={checked} onClick={() => onChange(!checked)} className="switch">
      <span className="thumb" aria-hidden />
      <span className="sr-only">{label}</span>
    </button>
  );
}
```
```css
.switch { inline-size: 2.5rem; block-size: 1.5rem; border-radius: 999px; background: var(--track-off); transition: background-color 150ms ease; }
.switch[aria-checked="true"] { background: var(--track-on); }
.thumb { display: block; inline-size: 1.25rem; block-size: 1.25rem; border-radius: 50%; background: white; translate: 0.125rem 0; transition: translate 180ms cubic-bezier(0.23,1,0.32,1); }
.switch[aria-checked="true"] .thumb { translate: 1.125rem 0; }
.switch:active .thumb { scale: 1.1 1; } /* subtle stretch on press */
```

### Instant subsequent tooltips (Radix)
Use `Tooltip.Provider delayDuration={400} skipDelayDuration={300}`. In CSS, apply the enter animation only when `[data-state="delayed-open"]`, and none for `instant-open`.

### Error shake with reduced-motion fallback
```css
@media (prefers-reduced-motion: no-preference) {
  .field[data-invalid="true"] { animation: shake 320ms ease-in-out; }
}
@keyframes shake { 25% { translate: -4px; } 50% { translate: 4px; } 75% { translate: -2px; } }
```
The error text and `aria-invalid`/`aria-describedby` carry the meaning.

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| Animating keyboard-driven list/palette highlight | Lags behind fast input | No animation |
| Spinner flashes for 50ms responses | Visual noise | Delay spinner ~300ms; min display 500ms once shown |
| Loading state changes button width | Layout shift, misclicks | Overlay spinner, fixed width |
| Hover effects on touch (sticky hover) | Stuck states after tap | `@media (hover: hover) and (pointer: fine)` |
| Scale from 0 / big bounces on menus | Cartoonish, slow | 0.96→1, no or minimal overshoot |
| Keyframe animations on toggles | Not interruptible; jumps on rapid clicks | Transitions |
| Motion-only success signal | Missed by screen readers/low vision | Text + live region |
| Confetti on routine actions | Loses meaning; distracting | Reserve for milestones |
| Delayed focus ring | Keyboard users lose place | Instant focus-visible |

## Accessibility
- WCAG 4.1.2 Name, Role, Value: state changes (`aria-checked`, `aria-pressed`, `aria-expanded`) must accompany visual toggles.
- WCAG 4.1.3 Status Messages: "Copied", "Saved", and errors are announced via `role="status"`/`aria-live="polite"`.
- WCAG 2.3.3: provide reduced-motion variants. Keep color and opacity changes; remove shake, bounce, and scale.
- WCAG 2.4.7/2.4.13 Focus Visible/Appearance: never animate focus indicators in ways that delay visibility.
- Keyboard activation: `:active` only applies while Space is held on buttons. Don't make feedback depend solely on `:active`; state changes should be visible too.
- Don't use motion to signal errors alone, and avoid rapid flashing (WCAG 2.3.1).

## Responsive Design
- Touch targets ≥ 24×24 CSS px (WCAG 2.5.8); press feedback matters more on touch because there's no hover.
- Replace hover reveals with always-visible affordances on coarse pointers.
- Reduce scale/translate magnitudes on small components (icons: 0.9 press scale can read better than 0.97).
- Consider the Vibration API only as an optional enhancement on Android. It's not supported in iOS Safari, so never rely on it.

## Performance
- Use CSS transitions on `transform`/`opacity` with no JS per interaction.
- Avoid Motion components for every button in large lists; CSS is cheaper and keeps INP low.
- Event handlers should update state synchronously for feedback and defer heavy work (`startTransition`, `requestIdleCallback`) so feedback paints within one frame. This matters for INP.
- Lottie/Rive for micro-interactions: lazy-load and pause offscreen. Prefer CSS/SVG for tiny icons.

## Security
- Clipboard: `navigator.clipboard.writeText` requires a secure context and a user gesture. Never auto-copy on load. Avoid reading the clipboard without an explicit user action.

## Testing
- Testing Library: assert ARIA state (`aria-checked`, `role=status` text) after interaction, not animation.
- Playwright: rapid multi-click tests (no duplicate submits), `emulateMedia({ reducedMotion: 'reduce' })`, touch emulation for hover gating.
- Measure INP on key interactions using the Web Vitals extension or RUM.
- Visual regression of hover/active/focus states with animations disabled.

## Tooling
- CSS transitions + design tokens (primary).
- Motion for React for springs/gestures (Active).
- `lucide-react` icons for swap patterns (Active).
- NumberFlow (`@number-flow/react`) for animated number transitions (Community, Active).
- Radix/Base UI primitives expose `data-state` attributes for CSS-driven feedback.
- Sonner (toasts) and Vaul (drawers) bake in well-tuned motion (Community).

## Framework Notes
- **React (Vite SPA)**: keep micro-interactions in CSS keyed off `data-state`/ARIA attributes to avoid re-renders per frame. Use `useOptimistic` (React 19) so feedback appears before server confirmation.
- **Next.js App Router**: CSS-only interactions (press, hover) work in Server Components. Stateful ones (copy, toggles, optimistic likes) need `"use client"` leaf components. With Server Actions, use `useFormStatus` for pending button states and `useActionState` for results, and render pending feedback immediately.
- **Hydration**: before hydration, buttons in server HTML don't respond to clicks. CSS `:active` press feedback still shows, which can mislead users. Keep critical interactive controls light so hydration is fast, and avoid optimistic visual states that only JS can complete.

## AI Agent Guidance
- DO classify each interaction by frequency before adding motion.
- DO implement press/hover/toggle in CSS with tokens; DO gate hover to fine pointers.
- DO pair every visual confirmation with ARIA state or a live region.
- DON'T animate keyboard-driven navigation; DON'T delay focus rings; DON'T scale from 0.
- DON'T add an animation library just for micro-interactions.
- Verify: feedback appears within one frame; rapid clicks behave; screen reader announces status; reduced motion removes movement; no layout shift in loading states.

## Examples

### Optimistic like with subtle pop (Next.js Server Action)
```tsx
"use client";
import { useOptimistic, startTransition } from "react";
import { toggleLike } from "./actions";

export function LikeButton({ liked, count, postId }: { liked: boolean; count: number; postId: string }) {
  const [state, setOptimistic] = useOptimistic({ liked, count }, (s) => ({ liked: !s.liked, count: s.count + (s.liked ? -1 : 1) }));
  return (
    <button
      aria-pressed={state.liked}
      className="like"
      onClick={() => startTransition(async () => { setOptimistic(null); await toggleLike(postId); })}
    >
      <span className="heart" data-liked={state.liked} aria-hidden>♥</span>
      <span className="tabular-nums">{state.count}</span>
      <span className="sr-only">{state.liked ? "Unlike" : "Like"}</span>
    </button>
  );
}
```
```css
.heart { display: inline-block; transition: color 150ms ease; }
.heart[data-liked="true"] { color: var(--red-600); }
@media (prefers-reduced-motion: no-preference) {
  .heart[data-liked="true"] { animation: pop 300ms cubic-bezier(0.23,1,0.32,1); }
}
@keyframes pop { 40% { scale: 1.25; } }
```

## Related Skills
- [buttons-and-actions](../buttons-and-actions/Skill.md) — button states and semantics
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — toggle controls
- [tooltips](../tooltips/Skill.md) — tooltip delay behavior
- [toasts-and-notifications](../toasts-and-notifications/Skill.md) — toast motion
- [optimistic-ui](../optimistic-ui/Skill.md) — instant feedback with server actions
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — implementation mechanics
- [motion-design-principles](../motion-design-principles/Skill.md) — timing rationale
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcing status
- [inp-optimization](../inp-optimization/Skill.md) — responsiveness of interactions

## Sources
- [emilkowalski/skills emil-design-eng](https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md) — Community — duration table, press scale, frequency rules, hold-to-delete asymmetry
- [Emil Kowalski: 7 practical animation tips](https://emilkowal.ski/ui/7-practical-animation-tips) — Community — tooltips, origin-aware, scale
- [vercel-labs web-animation-design SKILL.md](https://github.com/vercel-labs/open-agents/blob/main/.agents/skills/web-animation-design/SKILL.md) — Community — easing decision flow, hover gating
- [Material 3 motion tokens](https://github.com/material-components/material-web) — Official/Open Source — duration scale
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion) — Official — purposeful, brief, interruptible feedback
- [Microinteractions (Dan Saffer)](https://microinteractions.com/) — Community — trigger/rules/feedback/loops model

## License / Usage Notes
Guidance synthesized from the cited sources; code is original. `lucide-react` is ISC, NumberFlow is MIT.

## Quality Tier
A — Grounded in practitioner rules and official guidance. Some timing values are opinionated defaults rather than standards.

## Status
Active

## Last Verified
2026-09-15
