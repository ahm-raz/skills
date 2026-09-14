# Microcopy and UX Writing

## Summary
Microcopy is the small text that makes interfaces usable: button labels, field labels, hints, errors, empty states, confirmations, tooltips, toasts, and notifications. This skill distills design-system content guidelines (GOV.UK, Atlassian, Mailchimp, Polaris, Material, Microsoft) into rules, formulas, and before/after examples, plus how to manage copy in a React/Next.js codebase.

## Category
UX

## Subcategories
button labels, form labels and hints, error messages, voice and tone, plain language, capitalization, terminology, inclusive language, i18n-ready copy

## Problem It Solves
Vague labels ("Submit", "OK"), jargon, inconsistent terminology, blaming or cute error messages, and truncation-prone strings slow users down and cause mistakes. Good copy often fixes usability issues faster than redesign.

## When To Use
- Writing any user-facing string.
- Reviewing UI PRs; building a glossary/voice guide; preparing for localization.

## When Not To Use
- Long-form marketing or documentation (related, but different structure) — still apply plain language.
- Legal text that must be verbatim (but add plain-language summaries around it).

## Core Principles
1. **Clarity over cleverness.** Users are mid-task; jokes and puns cost attention.
2. **Be concise and front-load the key words.** Cut filler ("in order to", "please note that").
3. **Use the user's language**, not internal jargon or system names.
4. **Be specific and actionable**: say what happens / what to do next.
5. **Consistent terminology**: one name per concept, everywhere.
6. **Buttons say what they do** (verb + noun): "Save changes", "Send invoice".
7. **Voice is constant, tone adapts**: calmer and simpler when things go wrong.
8. **Write for everyone**: plain language (aim ~grade 7-9 readability), inclusive, translatable.

## Best Practices
- Sentence case for UI text (headings, buttons, labels) — easier to read and localize.
- Use active voice and second person ("You can..."); first person for user-owned choices sparingly ("My projects").
- Avoid "please" and "sorry" in routine UI (GOV.UK, Atlassian); reserve apology for serious failures you caused.
- Avoid "invalid", "illegal", "error occurred", "oops", "something went wrong" without detail.
- Numbers as numerals ("3 files"); dates unambiguous and localized ("15 Sep 2026" or via `Intl.DateTimeFormat`).
- Don't use directional language that breaks in responsive layouts ("click the button on the right").
- Link text describes destination ("View billing history", not "Click here").
- Label + hint: label is a noun phrase ("Email address"); hint gives format/why ("We'll send a receipt here").
- Placeholder text never replaces labels; avoid example placeholders that look like filled values.
- Toast/confirmation: past tense, object named ("Invoice sent to Acme Ltd").
- Tooltips: supplementary only; never hide essential info in them.
- Keep a glossary and banned-words list in the repo.
- Leave 30-40% extra space for translation expansion (German, Finnish).

## Implementation Guidance

Formulas:

| Element | Formula | Example |
|---|---|---|
| Button | Verb + object | "Create project", "Export CSV" |
| Error | What happened + how to fix | "Card number is too short. Check it and try again." |
| Missing field error | Instruction | "Enter your postcode" |
| Empty state | What's empty + value + action | "No reports yet. Reports summarize weekly activity. Create report" |
| Confirmation dialog | Question naming object + consequence + verb buttons | "Remove Sam from Atlas? They'll lose access to 12 tasks. [Remove] [Cancel]" |
| Success toast | Object + past-tense verb | "Changes saved" / "3 members invited" |
| Loading | Present progressive, specific | "Importing contacts..." |
| Permission | What's blocked + who can help | "Only admins can change billing. Ask an admin." |
| Disabled control hint | Why + how to enable | "Add a payment method to publish" |

Before / after:

| Before | After | Why |
|---|---|---|
| "Submit" | "Create account" | Specific outcome |
| "Are you sure?" | "Delete 3 files?" | Names the object |
| "Invalid email" | "Enter an email address in the correct format, like name@example.com" | Actionable |
| "Your request could not be processed at this time." | "We couldn't save your changes. Try again." | Plain, active |
| "Utilize the dashboard to leverage insights" | "Use the dashboard to see trends" | Plain words |
| "Click here to learn more" | "Learn how billing works" | Descriptive link |
| "Oops! Looks like something broke 🙈" | "We couldn't load messages. Check your connection and try again." | Calm, specific |
| "No, I don't want to save money" | "No thanks" | No confirmshaming |

Copy management in code:

```ts
// messages/en.json (next-intl) — keys by feature, full sentences (no concatenation)
{
  "invoices": {
    "empty": { "title": "No invoices yet", "body": "Create an invoice to bill a client and track payment.", "cta": "Create invoice" },
    "sentToast": "Invoice sent to {client}",
    "count": "{count, plural, =0 {No invoices} one {# invoice} other {# invoices}}"
  }
}
```

```tsx
// app/[locale]/(app)/invoices/empty.tsx
import { getTranslations } from "next-intl/server";
export async function InvoicesEmpty() {
  const t = await getTranslations("invoices.empty");
  return <EmptyState title={t("title")} description={t("body")} primaryAction={<Link href="/invoices/new" className="btn-primary">{t("cta")}</Link>} />;
}
```

Rules for i18n-safe strings: never concatenate fragments ("You have " + n + " items"); use ICU plurals/select; keep variables named; give translators context comments; avoid idioms.

## Recommended Workflow
1. Draft copy with the actual component and realistic data, not lorem ipsum.
2. Apply formulas; cut words by ~30% on second pass.
3. Check glossary terms, capitalization, and banned words.
4. Read aloud; check with screen reader for label/hint/error order.
5. Test comprehension with users for critical flows (5-second / highlighter tests).
6. Externalize to message catalog; add translator notes.
7. Lint automatically (Vale / alex / custom ESLint rule for "click here", "please", "invalid").

## Patterns
- **Voice and tone matrix**: success (brief, warm), error (calm, direct), destructive (serious, specific), onboarding (encouraging, concise).
- **Hint text for format** before users make mistakes (error prevention).
- **Inline "why we ask"** for sensitive fields ("Used only for delivery updates").
- **Progressive specificity**: short label, expandable "More about X".
- **Consistent action verbs**: Create (new object), Add (existing to collection), Remove (from collection), Delete (destroy), Save (persist edits), Send (deliver).

## Anti-Patterns
- **Generic buttons** ("OK", "Yes", "Submit") — Fix: verb + object.
- **Synonym drift** ("workspace/team/org") — Fix: glossary + lint.
- **Title Case Everywhere** — slower reading, inconsistent. Fix: sentence case.
- **Humor in errors** — trivializes user problems. Fix: calm, specific.
- **String concatenation** — breaks translation. Fix: ICU messages.
- **Walls of help text** above forms — ignored. Fix: short hints at the point of need.
- **Confirmshaming / guilt copy** — manipulative. Fix: neutral opt-out labels.
- **Emoji as meaning carriers** — inconsistent rendering and screen reader verbosity. Fix: text; decorative emoji `aria-hidden`.

## Accessibility
- Labels or instructions (3.3.2); headings and labels descriptive (2.4.6); link purpose (2.4.4).
- Label in name (2.5.3): visible label text must be contained in the accessible name (e.g., `aria-label` starts with visible text).
- Plain language supports cognitive accessibility; define abbreviations on first use.
- Avoid sensory-only instructions ("the green button") (1.3.3).
- Set `lang` on `<html>` and on inline foreign-language phrases (3.1.1, 3.1.2).

## Responsive Design
- Write copy that survives narrow widths: short labels, avoid truncating button text; prefer wrapping to ellipsis for critical text.
- Provide shorter variants for mobile only if meaning stays identical (and keep accessible names consistent).

## Performance
- Load only the active locale's messages; split catalogs by route namespace for large apps.

## Security
- Don't reveal sensitive facts in copy (whether an email is registered, internal IDs).
- Escape interpolated user content (React does by default; avoid `dangerouslySetInnerHTML` for rich messages — use `t.rich`).
- Phishing-resistant copy: tell users what you will never ask for ("We'll never ask for your password by email").

## Testing
- Snapshot/visual tests with pseudo-localization (expanded strings, accented characters) to catch truncation.
- Lint with Vale or custom rules in CI; check missing translation keys.
- Comprehension tests for critical copy (pricing, consent, destructive actions).

## Tooling
- next-intl (App Router), react-intl/FormatJS, Lingui; Vale (prose linter, custom styles), alex (insensitive language), Hemingway-style readability checkers; Crowdin/Lokalise/Phrase for TMS.

## Framework Notes
- **Next.js (App Router)**: next-intl with `getTranslations` in Server Components (no client bundle cost) and `useTranslations` in Client Components; `generateMetadata` for localized titles.
- **React (Vite SPA)**: react-intl or Lingui with lazy-loaded locale catalogs; `Intl.*Format` APIs for numbers/dates.

## AI Agent Guidance
- Do: write specific verb+object buttons, formula-based errors and empty states; reuse existing glossary terms; externalize strings if the project uses i18n.
- Don't: use "Submit/OK", "Oops", "Invalid", "Click here", Title Case, or string concatenation; don't invent new names for existing concepts.
- Verify: grep new strings for banned words; check every error says how to fix; screen reader reads label + hint + error sensibly.

## Examples
```tsx
// Field with label, hint, and error following the patterns
<div>
  <label htmlFor="vat" className="font-medium">VAT number</label>
  <p id="vat-hint" className="text-sm text-neutral-600">Starts with a country code, like GB123456789</p>
  {error && <p id="vat-error" className="text-sm text-red-700"><span className="sr-only">Error: </span>{error}</p>}
  <input id="vat" name="vat" aria-describedby={error ? "vat-hint vat-error" : "vat-hint"} aria-invalid={!!error} autoComplete="off" />
</div>
```

## Related Skills
- [error-states](../error-states/Skill.md) — error message structure
- [empty-states](../empty-states/Skill.md) — empty-state copy
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — dialog copy
- [form-design-ux](../form-design-ux/Skill.md) — labels, hints
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — message catalogs
- [nextjs-internationalization](../nextjs-internationalization/Skill.md) — next-intl in App Router
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — plain language
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — trick wording and confirmshaming

## Sources
- [GOV.UK Design System: Error message](https://design-system.service.gov.uk/components/error-message/) — Official — message patterns, words to avoid
- [GOV.UK Content design: writing for GOV.UK](https://www.gov.uk/guidance/content-design/writing-for-gov-uk) — Official — plain English
- [Atlassian Design: Content / Error messages](https://atlassian.design/foundations/content/designing-messages/error-messages) — Official (design system) — voice principles, no sorry/please
- [Mailchimp Content Style Guide](https://styleguide.mailchimp.com/) — Community (CC BY-NC 4.0) — voice vs tone, accessible writing
- [Shopify Polaris: Content](https://polaris-react.shopify.com/content/actionable-language) — Official (design system) — actionable language, verb+noun buttons
- [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) — Official — sentence case, concise UI text
- [NN/g: UX Writing topic](https://www.nngroup.com/topic/writing-web/) — Community (research)

## License / Usage Notes
Mailchimp guide is CC BY-NC 4.0 (summarized, no verbatim reuse). GOV.UK OGL v3.0. Examples are original.

## Quality Tier
S — convergent guidance across several official design systems, with concrete formulas and i18n implementation.

## Status
Active

## Last Verified
2026-09-15
