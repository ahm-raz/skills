# Screen Reader Testing

## Summary
A practical procedure for manually testing React/Next.js UIs with the screen readers people actually use: NVDA and JAWS on Windows, VoiceOver on macOS and iOS, TalkBack on Android, and Narrator. It covers which browser pairings to use, essential commands, what to listen for, and how to write reproducible findings. Automated tools can't verify that announcements make sense. This does.

## Category
Accessibility

## Subcategories
NVDA, JAWS, VoiceOver, TalkBack, Narrator, browse vs focus mode, rotor, test scripts, AT/browser pairings, speech viewer

## Problem It Solves
axe and Lighthouse confirm that attributes exist, not that the experience works. Examples: a combobox that announces nothing when options filter, a route change that is silent, a toast read three times, a dialog whose content is unreachable with the virtual cursor. Only screen reader testing catches these. It also validates 1.3.1, 2.4.x, 3.3.x, 4.1.2 and 4.1.3 claims.

## When To Use
- Before release of any new component, flow or route template.
- When verifying ARIA widgets, live regions, dialogs, forms and client-side routing.
- When reproducing a user-reported AT issue.
- As part of a formal audit.

## When Not To Use
- Not as a replacement for automated scanning (do that first; it's cheaper).
- Don't "test" by only reading the accessibility tree. The tree is necessary, but screen reader behaviour (browse mode, verbosity, heuristics) differs.
- Don't claim a real user experience from sighted developer testing. Include disabled users in usability research.

## Core Principles
1. **Test the pairings users use.** WebAIM Screen Reader Survey #10 (2024), the latest:
   - Primary desktop: JAWS 40.5%, NVDA 37.7%, VoiceOver 9.7%.
   - Any use: NVDA 65.6%, JAWS 60.5%.
   - Mobile: 91.3% use a mobile screen reader, and VoiceOver dominates at 70.6%.
   - About 72% use more than one screen reader.
2. **Recommended pairings:**
   - NVDA + Chrome (or Firefox)
   - JAWS + Chrome
   - VoiceOver + Safari (macOS and iOS)
   - TalkBack + Chrome (Android)
   - Narrator + Edge as a secondary option
3. **Test tasks, not pages.** "Sign up", "filter results", "complete checkout".
4. **Use both navigation styles:** linear reading (arrows or swipes) and jump navigation (headings, landmarks, form fields, Tab).
5. **Listen for name, role, state and value, and for changes** after actions.
6. **Turn off the monitor or close your eyes** for at least one pass, to catch reliance on visuals.

## Best Practices
- Minimum release gate: NVDA+Chrome, and VoiceOver+Safari (macOS or iOS). Add JAWS for enterprise/US government audiences and TalkBack for Android-heavy audiences.
- Use the text output tools to record what was spoken:
  - NVDA Speech Viewer (NVDA menu > Tools)
  - VoiceOver Caption Panel (VoiceOver Utility > Visuals)
  - JAWS Speech History (Insert+Space, H)
- Reset verbosity to defaults before testing, since power-user settings hide issues.
- Test in production builds (`next build && next start`), not dev overlays.
- Record the screen reader version, browser version, OS, steps, actual vs expected announcement, SC reference and severity.
- Keep a regression script per critical flow and re-run it every release.

## Implementation Guidance

### Essential commands

**NVDA (Windows, free).** The NVDA key is Insert, or Caps Lock in the laptop layout.
| Action | Keys |
|---|---|
| Start/stop | Ctrl+Alt+N / NVDA+Q |
| Stop speech | Ctrl |
| Read all | NVDA+Down Arrow |
| Next/prev line | Down/Up Arrow (browse mode) |
| Headings / level | H, Shift+H / 1–6 |
| Landmarks | D, Shift+D |
| Form fields / buttons / links | F / B / K |
| Tables; cell navigation | T; Ctrl+Alt+Arrows |
| Lists / list items | L / I |
| Elements list (headings, links, landmarks) | NVDA+F7 |
| Toggle browse/focus mode | NVDA+Space |
| Read focused element | NVDA+Tab |

**JAWS (Windows, commercial; 40-minute demo mode)**
| Action | Keys |
|---|---|
| Read all | Insert+Down Arrow |
| Headings / list of headings | H / Insert+F6 |
| Regions (landmarks) | R |
| Form fields / list | F / Insert+F5 |
| Links list | Insert+F7 |
| Tables; cells | T; Ctrl+Alt+Arrows |
| Forms mode | Enter on field (auto); Esc or Numpad Plus to exit |
| Virtual cursor toggle | Insert+Z |
| Say focused element | Insert+Tab |

**VoiceOver (macOS).** VO = Ctrl+Option, or Caps Lock if configured.
| Action | Keys |
|---|---|
| Toggle VoiceOver | Cmd+F5 (or hold Touch ID button triple-press) |
| Next/prev item | VO+Right / VO+Left |
| Activate | VO+Space |
| Rotor (headings, links, landmarks, form controls) | VO+U, then Left/Right to switch lists |
| Next heading | VO+Cmd+H |
| Interact with group/table | VO+Shift+Down / VO+Shift+Up |
| Read all from cursor | VO+A |
| Describe item | VO+F3 |
| Quick Nav toggle (arrow-only navigation) | Left+Right Arrow together |

**VoiceOver (iOS/iPadOS)**
| Action | Gesture |
|---|---|
| Toggle | Settings > Accessibility > Accessibility Shortcut, then triple-click side button |
| Next/prev item | Swipe right/left |
| Activate | Double-tap |
| Rotor | Two-finger rotate; then swipe up/down to move by the chosen unit |
| Read all | Two-finger swipe up |
| Scroll | Three-finger swipe |
| Escape/back (close dialog) | Two-finger scrub (Z shape) |

**TalkBack (Android)**
| Action | Gesture |
|---|---|
| Toggle | Hold both volume keys 3 s (if shortcut enabled) |
| Next/prev item | Swipe right/left |
| Activate | Double-tap |
| Reading controls (headings, links, controls) | Swipe up/down to choose granularity (three-finger swipe or menu on newer versions) |
| TalkBack menu | Three-finger tap (or swipe down then right on older versions) |
| Back | Swipe right then left (or system back) |

**Narrator (Windows).** Toggle with Win+Ctrl+Enter. Scan mode is Caps Lock+Space. H/D/F navigate headings, landmarks and fields in scan mode.

### What to verify per component
| Component | Listen for |
|---|---|
| Page load / route change | Title or H1 announced; focus placement sensible |
| Headings / landmarks | Logical outline in the elements list or rotor; main, nav, banner, contentinfo labelled when duplicated |
| Links / buttons | Meaningful names out of context; role correct; `aria-pressed`/`aria-expanded` state spoken |
| Form fields | Label, role, required, invalid, hint and error text on focus |
| Errors | Error summary or inline errors announced after submit |
| Combobox | "combo box, collapsed/expanded"; option count; active option spoken while arrowing |
| Dialog | Dialog role and name on open; can't read background with the virtual cursor; focus returns on close |
| Tabs | "tab, 2 of 4, selected"; panel reachable |
| Tables | Caption; header cells spoken when moving across cells |
| Live updates | Toast or status spoken once, not interrupting unless urgent |
| Images | Meaningful alt; decorative images silent |
| Loading | Busy or "Loading" announced; results announced |

## Recommended Workflow
1. Run automated checks and fix violations first.
2. Write a task script: the steps and expected announcements for each critical flow.
3. NVDA+Chrome:
   - Linear read of the page with NVDA+Down.
   - Jump by H and D.
   - Complete the task with Tab plus browse-mode keys.
   - Record the Speech Viewer output.
4. VoiceOver+Safari on macOS: rotor review, then the same task.
5. VoiceOver on iOS Safari (and TalkBack on Chrome if relevant): swipe through, then complete the task, including the on-screen keyboard and dialogs.
6. Log issues with SC, severity (blocker/major/minor), reproduction steps, AT/browser versions, and the actual vs expected transcript.
7. Fix, re-test with the same script, and add automated regressions where possible (role/name assertions, focus assertions).

## Patterns
- **Transcript diff.** Save the Speech Viewer/Caption panel text per flow and diff it after refactors.
- **Task-based script template.** `Step | Action | Expected announcement | Actual | Pass/Fail | SC`.
- **Screen reader bug triage.** Reproduce in two screen readers. If only one fails with valid markup, check ARIA-AT or the AT's bug tracker before hacking around it.

## Anti-Patterns
- **Testing only with VoiceOver on macOS.** It is the least-used desktop reader and has distinct heuristics. Include NVDA.
- **Tabbing only.** Screen reader users mostly read with the virtual cursor and jump commands. Content not reachable by Tab (text, errors) goes untested.
- **"Fixing" by adding `aria-label` everywhere.** Overrides visible text and breaks voice control. Fix the semantics.
- **Hacks targeting one screen reader** (user-agent sniffing, `role="application"`). Fix the standards-based markup and report AT bugs.
- **Testing in dev mode with the React error overlay or HMR** changing the DOM. Use production builds.

## Accessibility
- Validates 1.1.1, 1.3.1, 1.3.2, 2.4.2, 2.4.3, 2.4.4, 2.4.6, 3.3.1, 3.3.2, 4.1.2 and 4.1.3 in practice.
- Supports the "accessibility supported" conformance requirement: document the AT tested.

## Responsive Design
- Mobile screen readers use touch exploration. Test that controls are discoverable by swiping, that off-canvas nav is hidden when closed, and that sticky elements don't trap swipe order.
- Test at mobile viewport on real devices where possible. Desktop emulation doesn't run mobile screen readers.

## Performance
- Very large DOMs (thousands of nodes) make NVDA and JAWS sluggish in browse mode. Virtualize long lists, but keep accessible counts (`aria-setsize`).
- Excessive live-region updates cause speech floods and lag. Debounce.

## Security
- Screen readers speak masked password fields as "star" or silent, which is expected. Never put sensitive data in `aria-label` or `title` that isn't visible.
- Don't record testing sessions containing real customer data. Use fixtures.

## Testing
- **Manual (this skill).** Scripts plus transcripts.
- **Complementary automation.**
  - Testing Library role and name queries.
  - Playwright `toMatchAriaSnapshot()` to snapshot the accessibility tree (catches regressions in roles and names, but not speech output).
  - Guidepup (open source) can drive VoiceOver and NVDA in CI for smoke checks. Treat it as experimental and flaky.
- W3C ARIA-AT reports show expected output for APG patterns across JAWS, NVDA and VoiceOver.

## Tooling
- NVDA (free, GPL; NV Access), JAWS (Freedom Scientific/Vispero, commercial), VoiceOver (built into Apple OSes), TalkBack (Android Accessibility Suite), Narrator (Windows).
- Virtual machines: use a Windows VM on a Mac for NVDA/JAWS. Assistiv Labs and BrowserStack offer cloud screen reader access.
- Guidepup + `@guidepup/playwright` (experimental automation), Playwright ARIA snapshots.
- Chrome and Firefox accessibility inspectors.

## Framework Notes
- **Next.js.**
  - Test client-side navigation specifically: the built-in route announcer reads the new title, but verify focus placement.
  - Test `loading.tsx` and Suspense streaming (do users hear "loading" then content?), and intercepted-route modals.
  - Hydration mismatches can duplicate or remove nodes. Test after hydration completes.
- **React (Vite SPA).**
  - There is no built-in announcer, so verify that each route change is announced.
  - Portaled overlays (Radix, React Aria) render at the end of `body`. Check that virtual cursor order still makes sense and that the background is hidden while modal.
- **Both.** Confirm conditional rendering doesn't recreate live regions, which silently drops announcements.

## AI Agent Guidance
- Do: produce a screen reader test script (steps plus expected announcements) for each flow you build, and hand it to a human if you can't run AT.
- Do: use Playwright ARIA snapshots and role queries as automated proxies. Clearly state that real screen reader testing is still required.
- Don't: claim "tested with screen readers" unless actually performed. Say "accessibility tree verified; manual SR testing pending".
- Don't: add screen-reader-specific hacks.
- Verify before done: accessibility tree matches expectations; the script is written; the known limitations are documented.

## Examples
```ts
// e2e/signup.aria.spec.ts – automated proxy for SR expectations (Playwright)
import { test, expect } from '@playwright/test';

test('signup form accessibility tree', async ({ page }) => {
  await page.goto('/signup');
  await expect(page.getByRole('main')).toMatchAriaSnapshot(`
    - heading "Create your account" [level=1]
    - textbox "Email"
    - textbox "Password"
    - checkbox "I agree to the terms"
    - button "Create account"
  `);
});
```

```md
<!-- Test script row format -->
| # | Action (NVDA + Chrome) | Expected | Actual | Result | SC |
|---|---|---|---|---|---|
| 1 | Load /signup | "Create your account – Acme", H1 "Create your account" | | | 2.4.2 |
| 2 | Press F | "Email, edit, required" | | | 1.3.1, 3.3.2 |
| 3 | Submit empty | "There is a problem" alert; focus on summary | | | 3.3.1, 4.1.3 |
```

## Related Skills
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) — run first; complements manual testing
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — what should be announced
- [accessible-spa-routing](../accessible-spa-routing/Skill.md) — route change announcements
- [accessibility-audit-process](../accessibility-audit-process/Skill.md) — where SR testing fits in an audit
- [cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md) — device labs
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) — ARIA snapshots

## Sources
- [WebAIM Screen Reader User Survey #10](https://webaim.org/projects/screenreadersurvey10/) — Community research — usage shares and pairings
- [NVDA User Guide / Commands Quick Reference](https://www.nvaccess.org/files/nvda/documentation/userGuide.html) — Official (vendor) — NVDA keys
- [Apple VoiceOver User Guide](https://support.apple.com/guide/voiceover/welcome/mac) — Official (vendor) — VO commands
- [Freedom Scientific JAWS keystrokes](https://www.freedomscientific.com/training/jaws/hotkeys/) — Official (vendor) — JAWS keys
- [Android TalkBack gestures](https://support.google.com/accessibility/android/answer/6151827) — Official (vendor) — TalkBack gestures
- [W3C ARIA-AT](https://aria-at.w3.org/) — Official — AT interoperability expectations
- [Deque: screen reader testing guides](https://dequeuniversity.com/screenreaders/) — Community (vendor) — shortcut references
- [Playwright ARIA snapshots](https://playwright.dev/docs/aria-snapshots) — Open Source — automated tree assertions

## License / Usage Notes
Command tables are summarised from vendor documentation. Survey figures are cited from WebAIM. No proprietary text is copied.

## Quality Tier
A — comprehensive and current. Survey data is from 2024 (latest available), and TalkBack gestures vary by Android version.

## Status
Active

## Last Verified
2026-09-15
