# Onboarding UX

## Summary
Onboarding is everything between a user's first visit/signup and their first meaningful success ("aha" / activation). Good onboarding removes steps before value, personalizes lightly, teaches in context rather than via up-front tours, and leaves users with a working setup. This skill covers activation-driven design, pattern selection (checklists, empty-state onboarding, contextual tips, templates), and React/Next.js implementation.

## Category
UX

## Subcategories
first-run experience, activation, setup checklists, product tours, contextual help, personalization questions, sample data, re-onboarding

## Problem It Solves
Long signup forms, multi-screen carousels and forced product tours delay value; users skip them and still don't know what to do. Low activation means paid acquisition is wasted.

## When To Use
- New products or features with a setup cost (integrations, importing data, inviting teammates).
- Activation metrics lag signups; support tickets show "how do I start?".
- Launching a significant new feature to existing users.

## When Not To Use
- Simple, self-explanatory apps where the first screen is the value (don't add a tour to a calculator).
- As a fix for a confusing core UI — fix the UI first (tutorials don't fix usability problems).

## Core Principles
1. **Define activation first**: the specific action correlated with retention (e.g., "created first project and invited 1 teammate within 7 days").
2. **Get to value fast**: remove, defer or prefill every step not required for first success.
3. **Teach in context, when needed** (pull revelations) rather than up-front tours users forget (Paradox of the Active User: users don't read manuals).
4. **Show, don't describe**: templates, sample data, and real UI beat slideshows.
5. **Always skippable, always resumable**: users control pacing.
6. **Personalize only if you use the answer** immediately.
7. **Progress motivates** (Goal-Gradient, Zeigarnik): checklists with visible progress, pre-completed first item.
8. **Onboarding ends**: dismissible, and it disappears once done.

## Best Practices
- Signup: email or SSO/passkey only; collect name/company later or infer.
- Welcome screen: one question max that changes the experience ("What will you use this for?"), with "Skip".
- Setup checklist (3-5 items) on home: each item links to the exact place to do it; mark completed automatically based on real data.
- Empty states double as onboarding: explain + primary CTA + template.
- Contextual tips: single tooltip/popover anchored to a new feature, shown once, dismissible; max one at a time.
- Product tours only for complex layouts; <= 3-5 steps; never block the UI; triggered by user ("Take a tour") or first visit with easy skip.
- Import/integrations early when data is the value (CSV import, connect GitHub).
- Invite teammates at the moment collaboration matters (after creating a first object), not on step 1.
- Celebrate the first success briefly and point to the next step.
- Re-engage via email only with helpful, actionable next steps; respect opt-out.

## Implementation Guidance

Pattern selection:

| Situation | Pattern |
|---|---|
| Value depends on user's own data | Import/connect step + sample data fallback |
| Many possible starting points | Templates gallery |
| Multi-part setup | Persistent checklist with progress |
| Simple app, obvious primary action | Strong empty state only |
| New feature for existing users | One contextual popover + changelog link |
| Complex canvas/editor | Optional 3-step tour + inline hints |
| Different roles/use cases | One personalization question -> tailored checklist |

Data model: store onboarding state server-side (not localStorage only) so it follows users across devices.

```ts
// lib/onboarding.ts — derive checklist from real data, not clicks
export type ChecklistItem = { id: string; title: string; description: string; href: string; done: boolean };
export async function getChecklist(workspaceId: string): Promise<ChecklistItem[]> {
  const [projects, members, integrations] = await Promise.all([countProjects(workspaceId), countMembers(workspaceId), countIntegrations(workspaceId)]);
  return [
    { id: "account", title: "Create your account", description: "Done", href: "/settings/profile", done: true }, // pre-completed = goal-gradient
    { id: "project", title: "Create your first project", description: "Start from a template or a blank project.", href: "/projects/new", done: projects > 0 },
    { id: "connect", title: "Connect GitHub", description: "Link commits and pull requests to tasks.", href: "/settings/integrations", done: integrations > 0 },
    { id: "invite", title: "Invite a teammate", description: "Projects work best with your team.", href: "/settings/members?invite=1", done: members > 1 },
  ];
}
```

```tsx
// app/(app)/home/onboarding-checklist.tsx — Server Component + client dismiss
import Link from "next/link";
import { getChecklist } from "@/lib/onboarding";
import { DismissButton } from "./dismiss-button";

export async function OnboardingChecklist({ workspaceId, dismissed }: { workspaceId: string; dismissed: boolean }) {
  if (dismissed) return null;
  const items = await getChecklist(workspaceId);
  const done = items.filter((i) => i.done).length;
  if (done === items.length) return null;
  return (
    <section aria-labelledby="setup-h" className="rounded-lg border p-5">
      <div className="flex items-center justify-between">
        <h2 id="setup-h" className="font-semibold">Get set up</h2>
        <DismissButton />
      </div>
      <p className="text-sm text-neutral-600">{done} of {items.length} complete</p>
      <progress className="mt-2 w-full" max={items.length} value={done} aria-label="Setup progress" />
      <ol className="mt-4 space-y-3">
        {items.map((i) => (
          <li key={i.id} className="flex gap-3">
            <span aria-hidden>{i.done ? "✓" : "○"}</span>
            <div>
              {i.done ? <span className="text-neutral-500 line-through">{i.title}</span> : <Link href={i.href} className="font-medium underline-offset-2 hover:underline">{i.title}</Link>}
              <span className="sr-only">{i.done ? " (completed)" : " (not completed)"}</span>
              {!i.done && <p className="text-sm text-neutral-600">{i.description}</p>}
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}
```

## Recommended Workflow
1. Identify activation event via retention cohort analysis.
2. Map the current path from landing to activation; count steps, fields, decisions.
3. Remove/defer/prefill steps; decide pattern(s) from the table.
4. Write copy (value-first, short) and design empty states as onboarding.
5. Implement server-side state; instrument each step (viewed, completed, skipped).
6. Test with 5 new users (think-aloud) who've never seen the product.
7. A/B test major changes against activation, not tour completion.

## Patterns
- **Setup checklist** with auto-completion from real data.
- **Template-first start** ("Start with a template" grid + blank).
- **Sample workspace** clearly labeled, one-click delete.
- **Contextual popover "New"** anchored to the feature, once.
- **Welcome question** that filters templates/checklist.
- **Deferred account creation**: try first, save by signing up.

## Anti-Patterns
- **Welcome carousel of feature slides** — skipped, forgotten. Fix: contextual education and empty states.
- **Forced unskippable tour** — frustrating, blocks exploration. Fix: optional, short, resumable.
- **Asking 8 profile questions up front** — drop-off. Fix: ask one, only if used.
- **Tooltip storms** (5 hotspots at once) — Fix: one at a time, triggered by relevance.
- **Checklist items marked done by clicking** rather than doing — false progress. Fix: derive from data.
- **Onboarding that never goes away** — Fix: auto-hide when complete; dismissible anytime.
- **Invite spam gate** ("Invite 3 friends to continue") — forced action dark pattern. Fix: optional invites.

## Accessibility
- Tours/popovers: focus management (move focus into popover, return on close), Esc to dismiss, not trapping users (2.1.2), announced with dialog/tooltip semantics.
- Progress conveyed in text, not only rings/colors (1.4.1).
- Don't auto-advance slides/steps on timers (2.2.1, 2.2.2).
- Checklist status available to screen readers ("completed").

## Responsive Design
- Checklists collapse to a compact progress card on mobile.
- Avoid anchored multi-step tours on mobile; use inline cards or a single sheet.

## Performance
- Load tour libraries lazily only for users who need them (`next/dynamic`).
- Server-render checklist; avoid client waterfalls on home.

## Security
- Integrations in onboarding: explain permissions requested (OAuth scopes) in plain language; request least privilege.
- Sample data must not be real customer data.

## Testing
- E2E with a fresh account: complete activation path; checklist items auto-complete; dismiss persists across devices.
- Analytics funnel for each step; cohort retention by activation.
- Usability tests with first-time users.

## Tooling
- Product analytics (PostHog, Amplitude, Mixpanel) for activation funnels; tour libraries (Onborda for Next.js, driver.js, React Joyride) — use sparingly; feature flags for staged rollouts.

## Framework Notes
- **Next.js (App Router)**: compute onboarding state in Server Components; store dismissal via Server Action (DB or cookie); `next/dynamic` with `ssr: false` for tour libraries in client components; route to `/welcome` via proxy/middleware-free server redirect in the app layout when profile incomplete (avoid redirect loops).
- **React (Vite SPA)**: fetch onboarding state with the user query; lazy-load tour code; persist server-side via API.

## AI Agent Guidance
- Do: identify the activation event and design the shortest path; derive progress from data; make everything skippable; build empty states as onboarding.
- Don't: add carousels or forced tours by default; don't ask questions you won't use.
- Verify: fresh-account walkthrough, skip/dismiss persists, keyboard and screen reader can use tour/checklist.

## Examples
```tsx
// Contextual "New" popover shown once for a feature (client)
"use client";
import * as Popover from "@radix-ui/react-popover";
import { markHintSeen } from "./actions";
export function FeatureHint({ seen, children }: { seen: boolean; children: React.ReactNode }) {
  return (
    <Popover.Root defaultOpen={!seen} onOpenChange={(open) => { if (!open) markHintSeen("bulk-edit"); }}>
      <Popover.Anchor asChild>{children}</Popover.Anchor>
      <Popover.Portal>
        <Popover.Content side="bottom" className="max-w-xs rounded-md bg-neutral-900 p-3 text-sm text-white">
          <p><strong>New:</strong> select multiple rows to edit them at once.</p>
          <Popover.Close className="mt-2 underline">Got it</Popover.Close>
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
```

## Related Skills
- [empty-states](../empty-states/Skill.md) — first-use states as onboarding
- [user-flow-design](../user-flow-design/Skill.md) — mapping the activation path
- [progressive-disclosure](../progressive-disclosure/Skill.md) — revealing complexity over time
- [authentication-ux](../authentication-ux/Skill.md) — low-friction signup
- [conversion-ux](../conversion-ux/Skill.md) — signup-to-activation funnel
- [popovers](../popovers/Skill.md) — contextual hint component
- [feature-flags-and-experimentation](../feature-flags-and-experimentation/Skill.md) — testing onboarding variants
- [saas-application-patterns](../saas-application-patterns/Skill.md) — SaaS context

## Sources
- [NN/g: Mobile-App Onboarding: An Analysis of Components and Techniques](https://www.nngroup.com/articles/mobile-app-onboarding/) — Community (research) — tutorials often skipped; contextual help preferred
- [NN/g: Onboarding Tutorials vs. Contextual Help](https://www.nngroup.com/articles/onboarding-tutorials/) — Community — pull revelations
- [Laws of UX: Goal-Gradient, Zeigarnik, Paradox of the Active User](https://lawsofux.com/) — Community
- [Material Design: Onboarding](https://m2.material.io/design/communication/onboarding.html) — Official (legacy M2 guidance) — self-select, quickstart models
- [Page Flows / Mobbin onboarding flows](https://pageflows.com/) — Community (inspiration) — real-world flow references

## License / Usage Notes
Principles summarized; code original. Inspiration sites used only for pattern observation.

## Quality Tier
A — research-backed; activation specifics vary by product.

## Status
Active

## Last Verified
2026-09-15
