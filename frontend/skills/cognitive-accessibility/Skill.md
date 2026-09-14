# Cognitive Accessibility

## Summary
Designing and building React/Next.js interfaces usable by people with cognitive and learning disabilities: memory, attention, language, literacy, executive function, and mental health conditions, as well as anyone tired, stressed or distracted. Grounded in the W3C COGA guidance "Making Content Usable for People with Cognitive and Learning Disabilities", the WCAG 2.2 criteria that target cognition, and plain language standards. Much of COGA sits beyond WCAG AA, so this skill covers both the requirements and high-value supplemental patterns.

## Category
Accessibility

## Subcategories
COGA, plain language, memory load, attention and distraction, consistent help, redundant entry, accessible authentication, timeouts, error prevention, undo, progress indicators, readable typography

## Problem It Solves
Interfaces that demand memorising codes, solving puzzles to log in, re-entering data, deciphering jargon, recovering from cryptic errors, racing timeouts, or navigating inconsistent layouts exclude a large population. Cognitive disabilities are among the most common disabilities. WCAG AA historically covered them thinly, so WCAG 2.2 added 3.2.6, 3.3.7 and 3.3.8, and WCAG 3 drafts expand this area further.

## When To Use
- Any user flow: sign-up and login, checkout, forms, settings, onboarding, error handling, notifications.
- Content writing and microcopy reviews.
- Designing timeouts, authentication, and destructive actions.

## When Not To Use
- There is no case where it's inappropriate. Scale the depth to the audience (healthcare, government, finance and education deserve the most rigour).

## Core Principles
The eight COGA objectives:
1. **Help users understand what things are and how to use them.** Familiar patterns, clear labels, conventional icons with text.
2. **Help users find what they need.** Clear navigation, search, consistent structure, headings.
3. **Use clear and understandable content.** Plain language, short sentences, literal wording, no unexplained jargon.
4. **Help users avoid mistakes and know how to correct them.** Forgiving inputs, clear errors, undo, confirmation for consequential actions.
5. **Help users focus.** Minimise distractions, interruptions and pop-ups; one main task per screen.
6. **Ensure processes don't rely on memory.** No re-entering, no recalling codes, show progress, save state.
7. **Provide help and support.** Consistent, easy-to-find help; human contact options.
8. **Support adaptation and personalisation.** Respect user settings (text size, spacing, motion, contrast); allow simplification.

## Best Practices
- **Plain language.** Target roughly a lower-secondary reading level for public content (WCAG 3.1.5 AAA). Follow ISO 24495-1 principles: relevant, findable, understandable, usable.
  - Front-load key information.
  - Use active voice.
  - Keep one idea per sentence.
  - Use "you"/"we".
- **Buttons say what happens:** "Pay £42.00", "Delete project", not "Submit" or "OK".
- **Icons with visible text labels** for primary actions; don't rely on icon-only meaning.
- **Consistent layout and help** (3.2.3, 3.2.4, 3.2.6): help/contact in the same place on every page.
- **Forgiving inputs:** accept phone numbers with spaces, dates in multiple formats, case-insensitive codes; trim whitespace.
- **Don't ask twice** (3.3.7): prefill, "same as billing", remember choices within the session.
- **Accessible authentication** (3.3.8): allow paste and password managers; support passkeys, magic links, "show password"; no puzzle CAPTCHAs; one-time codes via `autoComplete="one-time-code"` with a paste-friendly single field.
- **Timeouts** (2.2.1, 2.2.6 AAA): warn at least 2 minutes before, offer "Extend session"; tell users how long data is kept; autosave drafts.
- **Error prevention** (3.3.4, 3.3.6 AAA): review step before submitting legal or financial transactions; undo for destructive actions instead of (or as well as) confirm dialogs.
- **Progress and orientation:** step indicators ("Step 2 of 4: Delivery"), breadcrumbs, clear page titles.
- **Reduce distraction:** no autoplaying media, no carousels for key content, avoid modal interruptions (newsletter pop-ups), respect `prefers-reduced-motion`.
- **Chunking:** short paragraphs, bullet lists, headings every few paragraphs, progressive disclosure for advanced options.
- **Readable typography:** at least 16px base font, line-height about 1.5, line length about 45–80 characters (1.4.8 AAA guidance), left-aligned text (no justified), sufficient spacing; support user text-spacing overrides (1.4.12).
- **Avoid dark patterns:** confirmshaming, hidden costs, trick questions, forced continuity. These disproportionately harm users with cognitive disabilities.
- **Numbers and dates:** unambiguous formats ("15 September 2026"), explain calculations, show units.
- **AI chat and assistants:** clear disclosure, simple language, a way to reach a human, no time pressure.

## Implementation Guidance

### WCAG criteria most relevant to cognition
| SC | Level | Implementation |
|---|---|---|
| 1.3.5 Identify Input Purpose | AA | `autoComplete` tokens enable autofill and personalisation tools |
| 2.2.1 Timing Adjustable | A | Warn and extend timeouts |
| 2.2.2 Pause, Stop, Hide | A | Controls for moving content |
| 2.4.2 Page Titled / 2.4.6 Headings and Labels | A/AA | Descriptive titles and headings |
| 3.1.5 Reading Level | AAA | Plain language summaries |
| 3.2.3 Consistent Navigation / 3.2.4 Consistent Identification | AA | Shared layout components |
| 3.2.6 Consistent Help | A | Help link in the same place in layout |
| 3.3.1–3.3.3 Errors | A/AA | Specific, actionable messages |
| 3.3.4 Error Prevention (Legal, Financial, Data) | AA | Review, confirm, or reversible |
| 3.3.7 Redundant Entry | A | Prefill and reuse data |
| 3.3.8 Accessible Authentication (Minimum) | AA | No cognitive function tests without alternatives |

### Session timeout warning
```tsx
'use client';
import { useEffect, useRef, useState } from 'react';

export function SessionTimeoutWarning({ expiresAt, onExtend }: { expiresAt: number; onExtend: () => Promise<number> }) {
  const [expiry, setExpiry] = useState(expiresAt);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const warnAt = expiry - 2 * 60_000 - Date.now();
    const t = setTimeout(() => { setOpen(true); ref.current?.showModal(); }, Math.max(0, warnAt));
    return () => clearTimeout(t);
  }, [expiry]);

  return (
    <dialog ref={ref} aria-labelledby="to-title" aria-describedby="to-desc" onClose={() => setOpen(false)}>
      <h2 id="to-title">Do you need more time?</h2>
      <p id="to-desc">For your security, we will sign you out in 2 minutes. Your answers are saved.</p>
      <button type="button" autoFocus onClick={async () => { setExpiry(await onExtend()); ref.current?.close(); }}>
        Stay signed in
      </button>
      <form method="dialog"><button>Sign out now</button></form>
    </dialog>
  );
}
```

### Undo instead of confirm for reversible deletes
```tsx
const announce = useAnnounce();
async function archive(item: Item) {
  setItems(xs => xs.filter(x => x.id !== item.id));        // optimistic
  const undo = await archiveOnServer(item.id);               // returns an undo token
  toast(`Archived "${item.name}"`, {
    duration: 10_000,                                        // long enough; pauses on hover/focus
    action: { label: 'Undo', onClick: async () => { await undo(); setItems(xs => [item, ...xs]); announce('Restored'); } },
  });
}
```
Also provide a persistent "Recently archived" view, so undo isn't only available in a transient toast.

### Plain language microcopy checklist
| Instead of | Write |
|---|---|
| "Authentication failed" | "Your email or password is wrong. Try again or reset your password." |
| "Invalid input" | "Enter your phone number, like 07700 900 982" |
| "Submit" | "Send application" |
| "Are you sure?" | "Delete 3 photos? You can restore them for 30 days." |
| "Session expired due to inactivity" | "You were signed out because you were inactive for 30 minutes. Your answers are saved." |

## Recommended Workflow
1. Identify critical tasks and their cognitive load points (memory, reading, decisions, time pressure).
2. Content design first: plain language copy, error messages and help text, reviewed by a content designer.
3. Apply patterns: consistent layout and help, prefill and autosave, forgiving validation, undo, progress indicators, timeout warnings.
4. Remove barriers: cognitive CAPTCHAs, paste blocking, unnecessary steps and distractions.
5. Test with users with cognitive disabilities (moderated sessions, easy-read consent forms) and use the COGA usable-content checklist.
6. Measure: task completion, error rates, time on task, support contacts.

## Patterns
- **One thing per page** (GOV.UK pattern) for complex forms.
- **Check your answers** summary page before submit, with "Change" links.
- **Autosave with visible status:** "Saved 10:42" in `role="status"`.
- **Persistent help:** "Need help? Call 0800… or chat" in the same header or footer position.
- **Glossary tooltips/toggletips** for unavoidable terms, with the term also defined inline on first use.
- **Simplified mode setting**, hiding advanced options (progressive disclosure).

## Anti-Patterns
- **Puzzle or image CAPTCHAs.** 3.3.8 barrier. Use passkeys, email links, or invisible bot detection.
- **Blocking paste on password, email or OTP fields.** Forces recall and transcription. Allow paste.
- **Short silent timeouts that lose data.** Warn, extend, and autosave.
- **Vague errors ("Something went wrong").** Users can't recover. Explain what happened and what to do next.
- **Inconsistent button placement and labels across pages.** Relearning costs. Use shared components.
- **Walls of text, jargon, and double negatives** ("Uncheck to not receive…"). Write positively and concisely.
- **Dark patterns** (pre-checked upsells, confirmshaming, hidden unsubscribe). Harmful and increasingly illegal (EU DSA, FTC).
- **Interruptions** (pop-ups on load, chat bubbles bouncing, auto-rotating hero). Remove them, or delay until task completion.

## Accessibility
- WCAG A/AA: 1.3.5, 2.2.1, 2.2.2, 2.4.2, 2.4.6, 3.2.3, 3.2.4, 3.2.6, 3.3.1–3.3.4, 3.3.7, 3.3.8.
- AAA and supplemental: 2.2.6 Timeouts, 3.1.3 Unusual Words, 3.1.4 Abbreviations, 3.1.5 Reading Level, 3.3.5 Help, 3.3.6 Error Prevention (All), 3.3.9, and the COGA design patterns.
- Also respects user preferences: text spacing 1.4.12, reflow 1.4.10, reduced motion.

## Responsive Design
- Keep the same information architecture and help placement across breakpoints; don't hide essential guidance on mobile.
- Short line lengths suit mobile naturally. On desktop, constrain content width (`max-inline-size: 70ch`).

## Performance
- Fast, predictable responses reduce cognitive load. Show immediate feedback (optimistic UI with clear pending and saved states); avoid layout shifts that move targets (CLS).

## Security
- Balance security with 3.3.8: passkeys (WebAuthn) are both more secure and cognitively easier. Magic links and "remember this device" reduce recall.
- Session timeouts: communicate clearly and preserve data server-side (drafts) to avoid re-entry after re-authentication.

## Testing
- Content: readability tools (Hemingway, readable.com) as rough guides only. Human review by content designers. Test with target users.
- Heuristic review against the COGA "Objectives and Design Patterns" checklist.
- Automated partial checks: axe `autocomplete-valid`; unit tests that paste works on auth fields (`user.paste()`); Playwright tests for timeout warning and extension.
```tsx
test('allows pasting one-time code', async () => {
  const user = userEvent.setup();
  render(<OtpForm />);
  const input = screen.getByLabelText(/security code/i);
  await user.click(input);
  await user.paste('123456');
  expect(input).toHaveValue('123456');
});
```

## Tooling
- W3C COGA "Making Content Usable" (Group Note) and its design pattern list.
- GOV.UK Design System patterns (question pages, check answers, error messages) as tested references.
- Plain-language tools: Hemingway Editor, Microsoft Editor; ISO 24495-1 principles.
- Passkey libraries (SimpleWebAuthn), Auth.js / Better Auth with passkey support.

## Framework Notes
- **Next.js.**
  - Server Actions plus progressive enhancement keep forms working on slow devices.
  - Store drafts server-side (autosave via debounced actions).
  - Use shared `layout.tsx` for consistent navigation and help (3.2.3, 3.2.6).
  - `generateMetadata` for descriptive titles including step numbers.
- **React (Vite SPA).** Persist multi-step form state (URL, sessionStorage or server) so refreshes don't lose data. Use route loaders to prefill known data.

## AI Agent Guidance
- Do: write plain, specific microcopy (buttons describe outcomes, errors explain fixes); prefill known data; allow paste; add timeout warnings, autosave and undo for reversible actions; keep help in a consistent location.
- Do: flag content needing human review for reading level and tone.
- Don't: add CAPTCHAs, paste blocking, surprise pop-ups, jargon, vague errors, or dark patterns.
- Verify before done:
  - critical flows avoid re-entry and memory tests
  - errors are actionable
  - help is consistent
  - timeouts are handled
  - copy reviewed against the plain-language checklist

## Examples
See Implementation Guidance (timeout warning dialog, undo pattern, microcopy table) and Testing (paste test).

## Related Skills
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md) — writing clear UI text
- [accessible-forms](../accessible-forms/Skill.md) — labels, errors, redundant entry
- [authentication-ux](../authentication-ux/Skill.md) — accessible authentication flows
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — OTP and passkey inputs
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — undo vs confirm
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — progress and saving
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — harmful patterns
- [progressive-disclosure](../progressive-disclosure/Skill.md) — reducing complexity
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — distraction reduction

## Sources
- [W3C: Making Content Usable for People with Cognitive and Learning Disabilities (COGA)](https://www.w3.org/TR/coga-usable/) — Official (W3C Group Note) — objectives and design patterns
- [W3C WAI: Cognitive Accessibility at W3C](https://www.w3.org/WAI/cognitive/) — Official — overview and WCAG relationship
- [Understanding 3.2.6 Consistent Help / 3.3.7 Redundant Entry / 3.3.8 Accessible Authentication](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — new 2.2 criteria
- [GOV.UK Design System: Patterns](https://design-system.service.gov.uk/patterns/) — Official (government) — tested form and error patterns
- [ISO 24495-1:2023 Plain language](https://www.iso.org/standard/78907.html) — Official (standard) — plain language principles
- [WCAG 3 Working Draft news (March 2026)](https://www.w3.org/WAI/news/2026-03-03/wcag3) — Official — expanding cognitive outcomes in drafts

## License / Usage Notes
The COGA Group Note is under the W3C Document License. GOV.UK content is under OGL v3. ISO standards are copyrighted (principles summarised only). Code is original.

## Quality Tier
A — strong official guidance (COGA, WCAG 2.2). Many practices are beyond normative requirements and need user research to calibrate.

## Status
Active

## Last Verified
2026-09-15
