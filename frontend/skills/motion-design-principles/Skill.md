# Motion Design Principles

## Summary
Motion design principles explain why and how UI should move: which easing communicates what, how long things should take, how to choreograph multiple elements, and when not to animate at all. This skill turns Disney's 12 principles as applied to UI, Material 3 motion tokens, Apple HIG motion guidance, and practitioner work (Emil Kowalski, Josh Comeau on springs, Val Head, Rachel Nabors) into tokens and decision rules. It gives engineers and AI agents consistent, purposeful motion in React/Next.js apps.

## Category
Animation

## Subcategories
Easing, duration, choreography, springs, motion tokens, spatial models, purpose of motion, brand expressiveness, Disney principles for UI

## Problem It Solves
Without shared principles, every component picks arbitrary durations and easings. The result is inconsistent, slow, or gratuitous motion that distracts, delays users, and triggers vestibular issues. Principles and tokens make motion predictable, meaningful, and reviewable.

## When To Use
- Defining a design system's motion tokens and guidelines.
- Reviewing animation PRs ("why 600ms ease-in?").
- Choosing an animation for a new interaction (entry, exit, move, feedback).
- Briefing AI agents or designers on motion defaults.

## When Not To Use
- Implementation mechanics of a specific library; see the library skills.
- Illustrative/brand animation authored in After Effects/Rive, where animators own the curves (though the purpose rules still apply).

## Core Principles
1. **Purpose first**: motion must orient (where did it come from/go), provide feedback (it worked), show relationships (this came from that), or direct attention. Otherwise don't animate.
2. **Speed**: UI motion is fast. 100–300ms for most things; up to ~500ms for large surfaces; faster for frequent actions.
3. **Easing encodes physics and intent**: ease-out for entering and responding (arrives decisively), ease-in-out for moving on screen, ease-in only for elements leaving permanently (sparingly), linear only for continuous/progress motion.
4. **Frequency lowers expressiveness**: frequent → subtle or none; rare → can be expressive.
5. **Continuity**: objects shouldn't teleport. They transform from origin (transform-origin toward trigger, shared-element morphs).
6. **Spatial consistency**: a drawer that enters from the right exits to the right. Forward navigation moves left and back moves right (LTR).
7. **Interruptibility**: users can act mid-animation; motion must retarget, not queue.
8. **Respect preference**: reduced motion replaces movement with fades or instant changes.

## Best Practices
- Use duration by distance and size: small elements and short distances are shorter; full-screen surfaces are longer.
- Exits are ~20–30% faster than entries; users already decided to dismiss.
- Stagger lists at 20–50ms per item, capping total stagger around 300ms (animate only the first ~6–10 items).
- Enter from a nearby, meaningful origin (8–24px offset or scale 0.95), not from off-screen or scale 0.
- Use springs for gestures and physical elements (drag, sheets, toggles). Use duration-based easing for fades and color.
- Keep bounce subtle (0–0.25). Overshoot conveys playfulness, so reserve it for brand moments.
- Animate one primary thing at a time. Secondary elements follow with a small delay (follow-through/overlap).
- Define motion tokens in code and use them everywhere; ban raw ms/cubic-bezier values in components via lint or review.

## Implementation Guidance

### Easing semantics
| Intent | Easing | CSS value |
|---|---|---|
| Enter / respond to user | Strong ease-out | `cubic-bezier(0.23, 1, 0.32, 1)` |
| Standard (M3) | Standard | `cubic-bezier(0.2, 0, 0, 1)` |
| Large element entering (M3) | Emphasized decelerate | `cubic-bezier(0.05, 0.7, 0.1, 1)` |
| Element leaving permanently (M3) | Emphasized accelerate | `cubic-bezier(0.3, 0, 0.8, 0.15)` |
| Move within screen | Ease-in-out | `cubic-bezier(0.77, 0, 0.175, 1)` |
| Sheets/drawers (iOS feel) | Drawer | `cubic-bezier(0.32, 0.72, 0, 1)` |
| Hover color | Ease | `ease` |
| Progress, marquee, scrub | Linear | `linear` |
| Gesture release | Spring | Motion `{ type: "spring", duration: 0.4, bounce: 0.15 }` |

### Duration scale (Material 3 tokens, with typical UI mapping)
| Token | ms | Use |
|---|---|---|
| short1–short2 | 50–100 | Color/opacity feedback, selection |
| short3–short4 | 150–200 | Buttons, tooltips, small popovers |
| medium1–medium2 | 250–300 | Menus, cards expanding |
| medium3–medium4 | 350–400 | Dialogs, sheets |
| long1–long4 | 450–600 | Full-screen transitions (rare in web UI) |
| extra-long1–4 | 700–1000 | Brand/illustrative moments only |

### Disney's 12 principles applied to UI
| Principle | UI application | Use how often |
|---|---|---|
| Squash & stretch | Toggle thumb stretch on press; drag rubber-banding | Subtle |
| Anticipation | Button press-in (scale 0.97) before action | Common |
| Staging | Dim backdrop, focus attention on the dialog | Common |
| Straight-ahead vs pose-to-pose | Keyframes (pose-to-pose) for UI; physics (straight-ahead) for particles | — |
| Follow-through & overlapping action | Children settle slightly after container; staggered lists | Moderate |
| Slow in & slow out | Easing curves (never linear for objects) | Always |
| Arcs | Natural paths for FAB→sheet, thrown cards | Rare |
| Secondary action | Icon micro-motion accompanying main transition | Sparingly |
| Timing | Duration scale by size/distance | Always |
| Exaggeration | Error shake, celebration | Rare |
| Solid drawing | Consistent perspective/depth (shadows, z-order) | Always |
| Appeal | Brand-consistent, polished motion | Always |

### Should it animate?
| Question | If no → |
|---|---|
| Does it convey state, origin, relationship, or feedback? | Don't animate |
| Will users see it fewer than dozens of times per day? | Make it subtle or instant |
| Is it triggered by keyboard/power-user input? | Instant |
| Can it be interrupted without breaking? | Use transitions/springs |
| Is there a reduced-motion alternative? | Add one |

## Recommended Workflow
1. Write the motion purpose for each interaction (one sentence).
2. Assign an easing and duration token from the tables.
3. Choreograph: primary element first, secondary +30–60ms, exits faster.
4. Prototype in code (not just Figma). Motion feel only shows at real frame rates.
5. Review at 0.25x speed for jumps and at 1x for feel. Try doing the task 20 times in a row to feel repetition fatigue.
6. Define the reduced-motion alternative.
7. Codify as tokens and document them in the design system.

## Patterns

### Motion tokens in TypeScript (shared by CSS and Motion)
```ts
// lib/motion-tokens.ts
export const duration = { instant: 0.1, fast: 0.15, base: 0.2, moderate: 0.3, slow: 0.4 } as const;
export const ease = {
  out: [0.23, 1, 0.32, 1],
  inOut: [0.77, 0, 0.175, 1],
  drawer: [0.32, 0.72, 0, 1],
  standard: [0.2, 0, 0, 1],
  emphasizedDecel: [0.05, 0.7, 0.1, 1],
  emphasizedAccel: [0.3, 0, 0.8, 0.15],
} as const satisfies Record<string, readonly [number, number, number, number]>;
export const spring = {
  snappy: { type: "spring", duration: 0.3, bounce: 0 },
  gentle: { type: "spring", duration: 0.45, bounce: 0.15 },
} as const;
```
```css
/* app/globals.css — mirror tokens */
:root {
  --dur-fast: 150ms; --dur-base: 200ms; --dur-moderate: 300ms; --dur-slow: 400ms;
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
  --ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);
}
```

### Tailwind v4 theme tokens
```css
@theme {
  --ease-out-strong: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);
  --animate-fade-in: fade-in 200ms var(--ease-out-strong) both;
}
```

### Choreographed dialog
Backdrop fades in over 200ms. The panel scales 0.96→1 and fades over 200ms with ease-out, starting at the same time. Content has no separate animation. On exit, panel and backdrop fade over 150ms together.

### Directional spatial model
| Navigation | Old content | New content |
|---|---|---|
| Forward/deeper | Slides left (−60px) + fades | Enters from right (+60px) |
| Back | Slides right | Enters from left |
| Same level (tabs) | Crossfade | Crossfade |
| Overlay (sheet) | Stays; dims | From edge it's attached to |

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `ease-in` for entrances | Slow start feels laggy | Ease-out |
| Linear easing for objects | Robotic | Ease or spring |
| 500ms+ for menus/popovers | Sluggish; blocks flow | 150–250ms |
| Everything animates at once | No hierarchy | Primary first, stagger secondary |
| Long staggers on 50-item lists | Content appears slowly | Cap to first ~8 items; ≤300ms total |
| Inconsistent directions (drawer enters right, exits down) | Breaks spatial model | Symmetric paths |
| Bouncy overshoot on enterprise UI | Unserious, distracting | Bounce 0–0.1 |
| Decorative motion on every scroll section | Fatigue, vestibular risk | Reserve for key moments |
| Raw values sprinkled in components | Inconsistency | Tokens |

## Accessibility
- WCAG 2.3.3 Animation from Interactions: non-essential motion can be disabled. Reduced motion means replacing slides, zooms, parallax, and spins with fades or instant changes. Fades and color changes are generally acceptable.
- WCAG 2.2.2 Pause, Stop, Hide: auto-moving content over 5s needs controls.
- WCAG 2.3.1: no more than 3 flashes per second.
- Vestibular triggers to avoid or minimize: large-scale zoom, parallax at different speeds, spinning, full-screen slides, scroll-jacking.
- Cognitive load: motion should reduce confusion (continuity), not add it. Keep essential information static and readable.

## Responsive Design
- Distance scales with viewport, so duration should scale modestly (mobile full-width sheet ~300ms, desktop popover ~200ms).
- On touch devices, gestures should follow the finger 1:1 and then hand off to a spring with release velocity.
- Reduce expressive motion on small screens where it covers more of the visual field.

## Performance
- Principles assume smooth playback. A janky 60fps-intended animation violates "appeal"; see animation-performance.
- Shorter durations also reduce time spent in expensive states (blur, layers).

## Security
- Not applicable.

## Testing
- Design review checklist per animation: purpose, token used, direction consistency, interruptibility, reduced-motion variant.
- Record screen captures at 60fps and review frame-by-frame.
- Usability: watch users repeat the task. Motion that feels good once may annoy on the tenth repetition.
- Lint/grep for raw `cubic-bezier(` or `ms` values outside token files.

## Tooling
- Material 3 motion tokens (Official).
- Apple HIG Motion (Official).
- easings.co, easing.dev, and linear() generators for curve design.
- Motion for React springs (`duration` + `bounce` API).
- Rive/Lottie for authored brand motion.
- Emil Kowalski's animations.dev course and `emilkowalski/skills` agent skill (Community).

## Framework Notes
- **React (Vite SPA)**: export tokens from a TS module and consume them in Motion `transition` props. Mirror them as CSS custom properties for CSS transitions. Wrap the app in `MotionConfig` with default token transitions.
- **Next.js App Router**: tokens live in `app/globals.css` (CSS) and `lib/motion-tokens.ts` (TS). Server Components use CSS tokens; client components use both. Encode the directional spatial model in `Link transitionTypes` and `<ViewTransition>` CSS classes.

## AI Agent Guidance
- DO state the purpose of any animation you add, and use existing motion tokens (create them if missing).
- DO default to ease-out for entrances and 150–250ms durations for UI.
- DO keep spatial directions consistent and exits faster than entries.
- DON'T add decorative animation unprompted to high-frequency or keyboard-driven UI.
- DON'T use ease-in for entrances or bounce for enterprise apps.
- Verify: every new animation maps to a token, has a reduced-motion path, and passes the "should it animate?" table.

## Examples

### MotionConfig with tokens
```tsx
"use client";
import { MotionConfig } from "motion/react";
import { duration, ease } from "@/lib/motion-tokens";

export function MotionProvider({ children }: { children: React.ReactNode }) {
  return (
    <MotionConfig reducedMotion="user" transition={{ duration: duration.base, ease: ease.out }}>
      {children}
    </MotionConfig>
  );
}
```

## Related Skills
- [micro-interactions](../micro-interactions/Skill.md) — applying principles to feedback
- [css-animations-and-transitions](../css-animations-and-transitions/Skill.md) — token implementation in CSS
- [motion-for-react](../motion-for-react/Skill.md) — springs and variants
- [view-transitions-api](../view-transitions-api/Skill.md) — spatial navigation model
- [design-token-architecture](../design-token-architecture/Skill.md) — managing motion tokens
- [ui-design-principles-for-engineers](../ui-design-principles-for-engineers/Skill.md) — broader design fundamentals
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — safe alternatives
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — motion and cognitive load

## Sources
- [Material 3 motion tokens (material-web)](https://github.com/material-components/material-web) — Official/Open Source — easing and duration token values
- [Material 3: Easing and duration](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs) — Official — token semantics
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion) — Official — purposeful, brief, optional motion
- [emilkowalski/skills emil-design-eng](https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md) — Community — frequency rules, curves, durations
- [Josh Comeau: A friendly introduction to spring physics](https://www.joshwcomeau.com/animation/a-friendly-introduction-to-spring-physics/) — Community — springs vs easing, interruptibility
- [Emil Kowalski: animations.dev](https://animations.dev/) — Community — course context for design-engineering motion
- [Val Head: Designing Interface Animation](https://valhead.com/) — Community — purpose-driven UI animation
- [Rachel Nabors: Animation at Work](https://rachelnabors.com/) — Community — animation for communication and accessibility
- [Disney's 12 principles (Thomas & Johnston, The Illusion of Life)](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation) — Community — principle definitions

## License / Usage Notes
Principles are synthesized and paraphrased. Material tokens are Apache-2.0 via material-web. No verbatim copying.

## Quality Tier
A — Combines official token specs with established practitioner guidance. Some values are opinionated defaults. Val Head and Rachel Nabors are referenced from prior knowledge rather than fetched this session.

## Status
Active

## Last Verified
2026-09-15
