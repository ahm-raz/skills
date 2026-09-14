# Usability Heuristics

## Summary
Jakob Nielsen's 10 usability heuristics (NN/g, last updated January 2024) are broad rules of thumb for interaction design, used both as design guidance and as a structured method (heuristic evaluation) for finding usability problems without users. This skill maps each heuristic to concrete frontend checks, severity rating, and a lightweight review process engineers and AI agents can run on every UI change.

## Category
UX

## Subcategories
heuristic evaluation, UX review, severity rating, Laws of UX, cognitive load, error prevention, UI audit checklist

## Problem It Solves
Teams ship UI without a systematic quality lens; reviews devolve into taste debates. Heuristics provide shared vocabulary ("this violates recognition over recall") and a repeatable checklist that catches most common usability defects cheaply, before user testing.

## When To Use
- PR review of UI changes; pre-release UX audit.
- Evaluating competitor or legacy screens.
- Structuring AI agent self-review of generated UI.

## When Not To Use
- As a replacement for testing with real users (heuristics find likely problems, not proof).
- Validating product-market questions (whether the feature is wanted).

## Core Principles
The 10 heuristics, each with frontend checks:

1. **Visibility of system status** — loading indicators within ~1s, save status ("Saved 2m ago"), selected/active states, progress in multi-step tasks, upload progress.
2. **Match between system and the real world** — user vocabulary not DB fields ("Archived", not `is_deleted=2`), locale-formatted dates/currency, logical ordering.
3. **User control and freedom** — Cancel/Back everywhere, undo for destructive or bulk actions, Esc closes overlays, easy exits from flows.
4. **Consistency and standards** — same term and icon for same concept; platform conventions (links look like links, ctrl/cmd shortcuts); design-system components.
5. **Error prevention** — constraints (date pickers with min/max, disabled invalid options with explanation), confirmations for irreversible actions, sensible defaults, autocomplete.
6. **Recognition rather than recall** — visible labels (not placeholder-only), recent items, show selected filters as chips, keep context when editing.
7. **Flexibility and efficiency of use** — keyboard shortcuts, bulk actions, command palette, saved views, remember last choices.
8. **Aesthetic and minimalist design** — remove rarely used info from primary view; one primary action; progressive disclosure.
9. **Help users recognize, diagnose, recover from errors** — plain language, precise cause, how to fix, preserve input, no codes-only messages.
10. **Help and documentation** — contextual help (hint text, "Learn more" near complex fields), searchable docs, task-oriented.

## Best Practices
- Pair heuristics with Laws of UX for rationale: Hick's Law (choices), Fitts's Law (target size/distance), Doherty Threshold (<400ms), Miller/Chunking (grouping), Jakob's Law (familiarity), Tesler's Law (who absorbs complexity), Postel's Law (liberal input parsing).
- Evaluate with 3-5 evaluators independently, then merge: single evaluators find roughly a third of issues.
- Rate severity for prioritization (0-4).
- Evaluate task-by-task, not screen-by-screen, so gaps between screens are caught.
- Record each finding as: heuristic, location, evidence (screenshot), severity, recommendation.

## Implementation Guidance

Severity scale:

| Score | Meaning | Action |
|---|---|---|
| 0 | Not a usability problem | None |
| 1 | Cosmetic | Fix if time permits |
| 2 | Minor | Low priority |
| 3 | Major | Fix before release |
| 4 | Catastrophe (blocks task/causes data loss) | Fix immediately |

Severity factors: frequency, impact, persistence (can users learn around it?).

PR-ready heuristic checklist (copy into PR template):

```md
### UX heuristic check
- [ ] H1 Status: loading/saving/success feedback visible; long ops show progress
- [ ] H2 Language: no internal jargon, IDs or raw enums shown to users
- [ ] H3 Control: cancel/back/undo available; Esc closes overlays; no traps
- [ ] H4 Consistency: uses DS components; terms match glossary
- [ ] H5 Prevention: constraints & defaults; confirm or undo for destructive
- [ ] H6 Recognition: visible labels; current filters/selection visible
- [ ] H7 Efficiency: keyboard operable; bulk/shortcut where frequent
- [ ] H8 Minimalism: one primary action; secondary info disclosed on demand
- [ ] H9 Errors: specific message + fix + input preserved
- [ ] H10 Help: hints for complex inputs; link to docs where needed
```

Finding format:

```md
**[H9 | Severity 3] Payment failure message is generic**
Where: /checkout/payment after card decline
Evidence: "Error 402" toast disappears after 3s
Why: user can't tell whether charged or how to fix
Fix: inline alert above card field: "Your card was declined. Check the card details or use a different card." Keep form values; toast not auto-dismiss.
```

## Recommended Workflow
1. Define 3-6 key user tasks and the user profile.
2. Each evaluator walks each task twice: first for flow, second checking heuristics per step.
3. Log findings independently (spreadsheet/Linear issues with template).
4. Debrief: merge duplicates, agree severity.
5. Prioritize severity 3-4 fixes; turn recurring issues into design-system fixes or lint rules.
6. Validate critical fixes with 5-user usability test.

## Patterns
- **Status line**: "Saving..." -> "Saved" -> "Couldn't save. Retry" near the document title.
- **Undo toast**: "Conversation archived. Undo" (5-10s, pausable on hover/focus).
- **Chips for applied filters** with "Clear all".
- **Inline hint + example**: "Use 8+ characters. Example: `river-lamp-42`".
- **Forgiving input** (Postel): accept "+1 (555) 010-1234", "5550101234"; normalize.

## Anti-Patterns
- **Placeholder as label** (H6) — disappears on typing. Fix: persistent `<label>`.
- **Silent failures** (H1/H9) — Fix: explicit error UI + retry.
- **Confirm dialogs for everything** (H8/H5) — users auto-click through. Fix: undo for reversible, confirm only irreversible.
- **Inconsistent terms** "Delete / Remove / Trash" for the same action (H4). Fix: glossary.
- **Mandatory mouse** hover-only actions (H7 + a11y). Fix: visible or focusable controls.
- **Heuristics as a scorecard** ("we scored 8/10") — hides severity. Fix: prioritized findings list.

## Accessibility
Heuristics overlap WCAG but don't replace it. Map: H1 -> 4.1.3 status messages; H3 -> 2.1.2 no keyboard trap; H4 -> 3.2.3/3.2.4; H5 -> 3.3.4; H6 -> 3.3.2 labels; H9 -> 3.3.1/3.3.3. Run a WCAG check separately.

## Responsive Design
- Evaluate on a real phone: hover-dependent affordances, tiny targets (Fitts), truncated labels (H6) are mobile-specific heuristic failures.

## Performance
- H1 and Doherty Threshold: interactions acknowledged <100ms, results <400ms-1s; beyond ~10s show determinate progress and allow background/continue.

## Security
- H9 must not leak internals (stack traces, whether an email exists in login forms). Balance specificity against enumeration risk.

## Testing
- Heuristic evaluation (expert review) + usability testing (5 users per round) + analytics.
- Automate the automatable: axe (labels, contrast), Playwright tests for Esc closing dialogs, double-submit, error message presence.

## Tooling
- NN/g heuristic evaluation workbook (free download), spreadsheets/Linear templates, Maze/Lookback for follow-up tests, axe-core.

## Framework Notes
- **React (Vite SPA)**: encode heuristic-friendly defaults in shared components (Dialog closes on Esc via Radix/React Aria, Button has `pending` state, forms preserve values on error, undo toasts via Sonner).
- **Next.js (App Router)**: H1 via `loading.tsx` + Suspense and `useFormStatus`; H9 via `error.tsx` / `not-found.tsx` with recovery actions; H3 via real routes so Back works; Server Actions returning field errors through `useActionState` keep input (H9).

## AI Agent Guidance
- Do: after generating UI, walk the 10-point checklist and fix severity 3-4 issues before reporting done; report remaining lower-severity issues.
- Do: cite the heuristic when proposing changes, with a concrete fix.
- Don't: claim a UI is "usable" based only on heuristics; don't add confirmations as a blanket fix.
- Verify: loading, empty, error states exist; Esc/Back work; labels visible; error messages specific.

## Examples
```tsx
// H1 + H9: save status indicator with retry
function SaveStatus({ state, onRetry }: { state: "idle"|"saving"|"saved"|"error"; onRetry: () => void }) {
  return (
    <p role="status" aria-live="polite" className="text-sm text-neutral-600">
      {state === "saving" && "Saving..."}
      {state === "saved" && "All changes saved"}
      {state === "error" && (<>Couldn't save changes. <button className="underline" onClick={onRetry}>Try again</button></>)}
    </p>
  );
}
```

## Related Skills
- [ui-design-principles-for-engineers](../ui-design-principles-for-engineers/Skill.md) — applying Laws of UX in design
- [error-states](../error-states/Skill.md) — H9 in depth
- [loading-states](../loading-states/Skill.md) — H1 in depth
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — H3/H5
- [progressive-disclosure](../progressive-disclosure/Skill.md) — H8
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — complementary conformance check
- [ai-frontend-code-review](../ai-frontend-code-review/Skill.md) — automating reviews with agents
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — cognitive load overlap

## Sources
- [NN/g: 10 Usability Heuristics for User Interface Design](https://www.nngroup.com/articles/ten-usability-heuristics/) — Community (research) — heuristic names and intent (updated 2024-01-30)
- [NN/g: How to Conduct a Heuristic Evaluation](https://www.nngroup.com/articles/how-to-conduct-a-heuristic-evaluation/) — Community — process, multiple evaluators
- [NN/g: Severity Ratings](https://www.nngroup.com/articles/how-to-rate-the-severity-of-usability-problems/) — Community — 0-4 scale
- [Laws of UX](https://lawsofux.com/) — Community — supporting psychology principles
- [Vercel Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines) — Open Source (MIT) — concrete checks for agents

## License / Usage Notes
Heuristic names are widely cited; descriptions paraphrased. Checklists and code are original.

## Quality Tier
S — canonical, research-backed framework, stable for 30 years, mapped to actionable checks.

## Status
Active

## Last Verified
2026-09-15
