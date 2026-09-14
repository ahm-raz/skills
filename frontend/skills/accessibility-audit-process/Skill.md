# Accessibility Audit Process

## Summary
A repeatable, evidence-grade process for evaluating a React/Next.js product against WCAG 2.2 AA, following the W3C Website Accessibility Conformance Evaluation Methodology (WCAG-EM):
- scope
- explore
- sample
- evaluate
- report

Then remediation prioritisation, retesting, and producing an ACR/VPAT and accessibility statement. It complements automated CI testing with the structured manual evaluation that conformance claims require.

## Category
Accessibility

## Subcategories
WCAG-EM, audit scoping, sampling, manual evaluation, severity rating, ACT Rules, issue reporting, remediation planning, retesting, ACR/VPAT, accessibility statement, Trusted Tester

## Problem It Solves
Ad-hoc "a11y passes" produce inconsistent findings, miss complete processes, can't support legal or procurement claims, and leave teams with unprioritised issue dumps. A defined methodology gives defensible, comparable results and a clear remediation roadmap.

## When To Use
- Before launch, a major redesign, or a procurement bid needing an ACR.
- Annually, or per major release, for compliance evidence (EAA, ADA Title II, Section 508).
- When onboarding an acquired product or third-party component.
- After remediation, to verify and update statements.

## When Not To Use
- As a replacement for continuous shift-left practices (lint, CI axe, design review). Audits are periodic checkpoints.
- For a single component PR. Use component acceptance checklists instead.

## Core Principles
1. **Define scope and conformance target explicitly** (WCAG 2.2 AA; AT/browser baseline).
2. **Evaluate complete processes**, not just isolated pages.
3. **Use a representative sample**: templates, key flows, varied content, plus random pages.
4. **Test every applicable SC** with documented methods (automated, manual, AT).
5. **Findings are reproducible**: SC, location, steps, expected vs actual, evidence, severity, recommendation.
6. **Prioritise by user impact and reach**, not just SC level.
7. **Retest and record dates.** Conformance claims expire as code changes.
8. **Include people with disabilities** where possible. Expert audits and user testing find different issues.

## Best Practices
- Use the W3C WCAG-EM Report Tool or a spreadsheet template mapping SC to result per sample item.
- Align manual tests with W3C ACT Rules (Accessibility Conformance Testing), which harmonise how tools and auditors interpret SCs.
- Severity scale (example):
  | Severity | Definition | Example |
  |---|---|---|
  | Blocker | Prevents task completion for a user group | Checkout button unreachable by keyboard; CAPTCHA with no alternative |
  | High | Severe difficulty or workaround unreasonable | Form errors not announced; dialog doesn't trap or return focus |
  | Medium | Frustration, a workaround exists | Skipped heading levels; redundant links |
  | Low | Minor or best-practice | Decorative image has non-empty alt |
- Record the environment: NVDA 2026.x + Chrome, JAWS 2026 + Chrome, VoiceOver macOS 26 + Safari, iOS 26 VoiceOver, TalkBack + Chrome; Windows Contrast Themes; zoom levels.
- Separate "fails WCAG" from "usability recommendation" in reports.
- Remediation guidance at the component level. One design-system fix often resolves dozens of instances.
- Protect privacy: use test accounts and redact screenshots.

## Implementation Guidance

### WCAG-EM steps applied
| Step | Activities | Output |
|---|---|---|
| 1. Define scope | Product boundaries (domains, apps, authenticated areas); conformance target (WCAG 2.2 AA); AT/browser support baseline; exclusions (third-party, archived) | Scope statement |
| 2. Explore | Identify common components (header, nav, footer, forms, dialogs, tables), page templates (Next.js route groups), essential functionality, content types (video, PDFs), technologies relied upon (JS, ARIA, WebAuthn) | Inventory |
| 3. Select sample | Structured sample: every template plus complete processes (sign-up, login, search, checkout, account settings, support) plus pages with distinct content; a random sample of ~10% of the structured count for validation | Sample list (URLs and states) |
| 4. Audit sample | For each sample item and each SC: automated scan (axe/Accessibility Insights FastPass), manual checks (keyboard, zoom/reflow, text spacing, contrast of non-text, forced colors, reduced motion), screen reader task walkthroughs, cognitive review | SC-by-sample results, issues |
| 5. Report | Executive summary, scope and method, results per SC (Pass/Fail/Not present), issue list with severity and remediation, conformance statement (if claimed), date | Audit report, ACR inputs |

### Manual test checklist (per sample item)
1. **Page:** title unique (2.4.2), `lang` (3.1.1), landmarks and headings outline (1.3.1, 2.4.6), skip link (2.4.1).
2. **Keyboard:** full Tab walk, operability of all widgets, no traps, logical order, visible and unobscured focus (2.1.1, 2.1.2, 2.4.3, 2.4.7, 2.4.11).
3. **Zoom:** 200% text resize (1.4.4), 320px reflow (1.4.10), text spacing bookmarklet (1.4.12), hover/focus content (1.4.13).
4. **Color:** text contrast (1.4.3), non-text contrast (1.4.11), use of color (1.4.1), forced colors review.
5. **Images and media:** alt appropriateness (1.1.1), captions, transcripts, AD (1.2.x), autoplay (1.4.2), motion (2.2.2, 2.3.1).
6. **Forms:** labels and instructions (3.3.2), errors identified and suggested (3.3.1, 3.3.3), error prevention (3.3.4), redundant entry (3.3.7), authentication (3.3.8), autocomplete (1.3.5), on-input changes (3.2.2).
7. **Pointer:** target size (2.5.8), gestures and dragging (2.5.1, 2.5.7), cancellation (2.5.2), label in name (2.5.3), motion actuation (2.5.4).
8. **Screen reader task:** name, role and value (4.1.2), status messages (4.1.3), dialogs, routing announcements, tables.
9. **Consistency:** navigation (3.2.3), identification (3.2.4), help (3.2.6).
10. **Timing:** adjustable timeouts (2.2.1).

### Issue record template
```md
### [HIGH] Checkout: payment errors not announced (3.3.1, 4.1.3)
- **Location:** /checkout/payment — "Pay now" submit with an invalid card
- **Environment:** NVDA 2026.2 + Chrome 140, Windows 11
- **Steps:** 1) Enter card 4000 0000 0000 0002 2) Activate "Pay now"
- **Actual:** Red text "Card declined" appears below the form; nothing announced; focus stays on button.
- **Expected:** Error announced (focus error summary or role="alert"), linked to the card field via aria-describedby.
- **Users affected:** Screen reader users; cannot complete purchase.
- **Recommendation:** Use the design-system ErrorSummary; set aria-invalid and aria-describedby on CardField. See accessible-forms skill.
- **Component:** `components/checkout/PaymentForm.tsx` (affects 1 flow)
- **Evidence:** screenshot-payment-error.png, nvda-speech.txt
```

### From audit to ACR (VPAT)
- For each SC choose Supports / Partially Supports / Does Not Support / Not Applicable (Not Evaluated for AAA or out-of-scope items if the template allows).
- Remarks explain partial support with specific affected functionality ("Charts on Reports page lack text alternatives").
- Include the evaluation methods, dates, product version, and contact.
- Never mark "Supports" for SCs that weren't evaluated.

## Recommended Workflow
1. Kick-off: agree scope, target, AT baseline, timeline and stakeholders; get test accounts and a staging URL (production build).
2. Explore and build the sample (templates, flows, states) with the product team.
3. Automated sweep of the sample (axe/Accessibility Insights) to clear obvious issues and inform manual focus.
4. Manual evaluation per checklist, and screen reader tasks.
5. Consolidate issues: dedupe by component, assign severity, map to SCs, write recommendations.
6. Report and walkthrough with the team; import issues into the tracker with labels (`a11y`, `wcag-2.4.7`, `sev-high`).
7. Remediation sprints prioritised by severity × reach; fix in the design system first.
8. Retest the fixed issues plus a regression spot-check; update the report, ACR and accessibility statement with dates.
9. Convert recurring findings into automated tests and lint rules, and component acceptance criteria.

## Patterns
- **Component-first remediation:** group issues by shared component to maximise impact.
- **Audit-to-backlog pipeline:** a CSV or JSON export mapping into GitHub/Jira issues with SC labels.
- **Rolling audits:** audit one product area per sprint rather than a big-bang annual audit.
- **Dual-track:** expert audit plus usability sessions with disabled participants for critical flows.
- **Known-issues register** feeding the public accessibility statement.

## Anti-Patterns
- **Homepage-only audits.** Miss authenticated flows where tasks happen. Sample complete processes.
- **Automated-scan-as-audit reports.** Miss most manual SCs. Include manual and AT testing.
- **Issue dumps without severity or grouping.** Teams stall. Prioritise and group by component.
- **Auditing `next dev` or feature branches with debug tooling.** Unrepresentative. Use production builds.
- **Claiming conformance with open blockers.** Misrepresentation. State partial conformance with known issues.
- **No retest.** Fixes regress or are incomplete. Retest and date it.
- **Letting an AI tool generate the ACR without human verification.** Hallucinated passes. A human must verify.

## Accessibility
- Covers all WCAG 2.2 A/AA SCs via the checklist; optional AAA review where contracted.
- EN 301 549 audits add non-web clauses (e.g., 7 for video players, 11 for software, 12 for documentation and support).

## Responsive Design
- Include mobile viewport and real-device testing in the sample (iOS VoiceOver, Android TalkBack), and 320px reflow for every template.

## Performance
- Very slow pages hinder AT use. Note severe performance issues affecting accessibility (e.g., input delays with screen readers) as usability findings.

## Security
- Use dedicated test accounts and non-production data; redact PII in evidence; share reports on a need-to-know basis (reports reveal flaws that may have legal implications).
- Don't install unknown browser extensions or scripts on audit machines. Use vetted tools only.

## Testing
This skill is a testing process. Quality assurance of the audit itself: peer review of a sample of findings, and calibration of severity ratings across auditors, aligned with ACT Rules.

## Tooling
- W3C WCAG-EM Report Tool; W3C ACT Rules; W3C Accessibility Statement Generator.
- Accessibility Insights for Web (FastPass and Assessment), axe DevTools, WAVE, ARC Toolkit (TPGi), TPGi Colour Contrast Analyser, HeadingsMap, text-spacing bookmarklet.
- Screen readers: NVDA, JAWS, VoiceOver, TalkBack, Narrator.
- ITI VPAT® template; DHS Trusted Tester (Section 508 federal context).
- Issue trackers with SC labels; spreadsheet SC matrix.

## Framework Notes
- **Next.js.**
  - Map route groups and layouts to templates for sampling.
  - Include client navigation, `loading.tsx` states, intercepted modal routes, Server Action error states, and `not-found`/`error` pages in the sample.
  - Audit against the deployed production build (Vercel preview/staging).
- **React (Vite SPA).** Sample by router routes and key UI states (URL does not capture all states, so document the steps to reach each state).
- **Design system.** Audit Storybook components separately (state matrix) and reference component findings from page findings.

## AI Agent Guidance
- Do: help scope and inventory (list routes, components, flows from the codebase); run automated scans; draft issue records with SC mapping and code-level recommendations; generate the SC checklist per sample item.
- Do: clearly mark which checks were automated, which were agent-performed (e.g., keyboard via Playwright), and which require human screen reader or cognitive review.
- Don't: mark SCs as passing without evidence, fabricate screen reader output, or produce a final ACR without human sign-off.
- Verify before done:
  - every sample item has results for every applicable SC or an explicit "needs manual review"
  - issues have severity, SC, steps and recommendation
  - report dated with environment

## Examples
```md
## Audit summary – Acme Store (WCAG 2.2 AA) – 2026-09-15
- Scope: www.acme.example + account area; excludes third-party chat widget (vendor ACR requested)
- Sample: 14 templates, 5 complete processes, 3 random pages
- Method: axe-core 4.1x + Accessibility Insights Assessment; manual keyboard/zoom/contrast; NVDA+Chrome, VoiceOver+Safari (macOS/iOS)
- Result: Partially conformant — 0 blockers, 4 high, 11 medium, 6 low
- Top fixes: (1) ErrorSummary component for all forms, (2) Dialog focus return in Drawer, (3) Tabs selected state in forced colors, (4) Filter chip target size
```

## Related Skills
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — criteria being evaluated
- [screen-reader-testing](../screen-reader-testing/Skill.md) — AT task walkthroughs
- [automated-accessibility-testing](../automated-accessibility-testing/Skill.md) — automated layer and regression prevention
- [accessibility-legal-compliance](../accessibility-legal-compliance/Skill.md) — ACR and statement obligations
- [ai-accessibility-audit-workflow](../ai-accessibility-audit-workflow/Skill.md) — agent-assisted auditing
- [usability-heuristics](../usability-heuristics/Skill.md) — complementary usability evaluation

## Sources
- [W3C WCAG-EM 1.0 (Website Accessibility Conformance Evaluation Methodology)](https://www.w3.org/TR/WCAG-EM/) — Official — five-step methodology, sampling
- [W3C WCAG-EM Report Tool](https://www.w3.org/WAI/eval/report-tool/) — Official — structured reporting
- [W3C ACT Rules](https://www.w3.org/WAI/standards-guidelines/act/rules/) — Official — harmonised test rules
- [Accessibility Insights for Web – Assessment](https://accessibilityinsights.io/docs/web/getstarted/assessment/) — Open Source (Microsoft) — guided SC testing
- [ITI VPAT](https://www.itic.org/policy/accessibility/vpat) — Official (industry) — ACR template
- [DHS Trusted Tester](https://www.dhs.gov/trusted-tester) — Official (US gov) — Section 508 test process
- [W3C Accessibility Statements](https://www.w3.org/WAI/planning/statements/) — Official — statement guidance
- [Community-Access/accessibility-agents](https://github.com/Community-Access/accessibility-agents) — Community (MIT) — agent-based WCAG 2.2 review roles, reviewed as a reference for AI-assisted audit division of labour

## License / Usage Notes
W3C methodology is summarised. The VPAT® mark belongs to ITI. Templates here are original.

## Quality Tier
A — built on the official W3C methodology and widely used tooling. Severity scales are conventional rather than standardised.

## Status
Active

## Last Verified
2026-09-15
