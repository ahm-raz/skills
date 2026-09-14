# Settings and Preferences UX

## Summary
Designing settings pages and preference controls that users can find, understand and trust: structure (personal vs workspace vs object settings), save models (instant vs explicit save), control choice, defaults, search, permission-aware display, and system-preference integration (theme, motion, language). Includes Next.js App Router implementation with Server Actions and optimistic toggles.

## Category
UX

## Subcategories
account settings, workspace/admin settings, notification preferences, save models, defaults, settings search, theme/locale preferences, privacy controls

## Problem It Solves
Settings pages turn into junk drawers: unclear grouping, mixed save behaviors (some toggles instant, some need "Save"), unsaved changes lost on navigation, cryptic labels, and admin-only settings shown to everyone. Users can't find or trust controls, and support handles "where do I change X?".

## When To Use
- Building account, workspace/org, billing, notifications, privacy, integration, or per-object settings.
- Adding a new preference to an existing app.

## When Not To Use
- One-off configuration inside a creation flow (put it in the flow).
- Deciding whether to add a setting at all: first ask if a better default removes the need (every setting is a design decision deferred to users).

## Core Principles
1. **Prefer good defaults over settings**; add settings only for genuinely divergent needs.
2. **Organize by user mental model and scope**: Me (profile, security, notifications) / Workspace (members, billing, integrations) / Object (project settings on the project).
3. **One save model per section, visibly communicated.**
4. **Labels describe the outcome** ("Email me when someone mentions me"), not the implementation.
5. **Show consequences and current state** for impactful settings.
6. **Settings are findable**: navigation + search + deep links.
7. **Respect system preferences** (theme, reduced motion, language) as defaults users can override.
8. **Permission-aware**: show read-only with explanation or hide admin settings for non-admins.
9. **Privacy-protective defaults** (GDPR data protection by default).

## Best Practices
- Settings nav: left sidebar sections on desktop; list-to-detail on mobile.
- Instant-apply for toggles/switches with immediate, low-risk effects; confirm with subtle "Saved" status; provide undo for notable ones.
- Explicit save for forms with related fields (profile, billing address) or high-impact changes; sticky "Save changes" bar appears when dirty; warn on navigation with unsaved changes.
- Never mix: a switch inside an explicit-save form must not apply instantly.
- Switch = on/off immediate effect; checkbox = selection submitted with a form; radio = one of few mutually exclusive; select = one of many.
- Include descriptions under labels for non-obvious settings.
- Notification preferences as a matrix (event x channel) with sensible defaults and "Unsubscribe from all" honored.
- Dangerous settings in a separated "Danger zone".
- Setting search for large apps (command palette results include settings with deep links).
- Show inherited values ("Using workspace default: Weekly") with override controls.
- Log changes to sensitive settings (audit) and email notify security-relevant changes.

## Implementation Guidance

Save model decision:

| Setting type | Model | Feedback |
|---|---|---|
| Single binary preference (email digest on/off) | Instant | Inline "Saved" / toast; revert on error |
| Theme / density / language | Instant (local + server) | Immediate visual change |
| Related fields (name, address) | Explicit save | Dirty state bar; success message |
| Security (email, password, MFA) | Explicit + re-auth | Confirmation email |
| Workspace-wide impactful (SSO enforcement) | Explicit + confirm dialog | Summary of impact |
| Destructive (delete workspace) | Danger zone + confirm | See destructive-actions skill |

Scope structure (routes):

```
/settings/profile            (Me)
/settings/security           (Me)
/settings/notifications      (Me)
/settings/workspace/general  (Workspace, admin)
/settings/workspace/members  (Workspace, admin)
/settings/workspace/billing  (Workspace, billing role)
/projects/[id]/settings      (Object)
```

```tsx
// app/(app)/settings/notifications/toggle.tsx — instant-apply switch with optimistic state
"use client";
import { useOptimistic, useState, startTransition, useId } from "react";
import { updateNotificationPref } from "./actions";

export function PrefSwitch({ prefKey, label, description, initial }: { prefKey: string; label: string; description?: string; initial: boolean }) {
  const [value, setValue] = useState(initial);
  const [optimistic, setOptimistic] = useOptimistic(value);
  const [status, setStatus] = useState<"" | "Saved" | "Couldn't save. Try again.">("");
  const id = useId();
  return (
    <div className="flex items-start justify-between gap-6 py-4">
      <div>
        <label id={`${id}-l`} htmlFor={id} className="font-medium">{label}</label>
        {description && <p id={`${id}-d`} className="text-sm text-neutral-600">{description}</p>}
      </div>
      <div className="flex items-center gap-2">
        <span role="status" className="text-xs text-neutral-500">{status}</span>
        <button id={id} role="switch" aria-checked={optimistic} aria-describedby={description ? `${id}-d` : undefined}
          onClick={() => startTransition(async () => {
            const next = !optimistic;
            setOptimistic(next);
            const res = await updateNotificationPref(prefKey, next);
            if (res.ok) { setValue(next); setStatus("Saved"); } else { setStatus("Couldn't save. Try again."); }
          })}
          className="h-6 w-11 rounded-full bg-neutral-300 aria-checked:bg-brand-600">
          <span className="sr-only">{label}</span>
        </button>
      </div>
    </div>
  );
}
```

```tsx
// Explicit-save form with dirty tracking and sticky bar
"use client";
import { useActionState, useState } from "react";
import { saveProfile, type ProfileState } from "./actions";
export function ProfileForm({ initial }: { initial: ProfileState }) {
  const [state, action, pending] = useActionState(saveProfile, initial);
  const [dirty, setDirty] = useState(false);
  return (
    <form action={async (fd) => { await action(fd); setDirty(false); }} onChange={() => setDirty(true)}>
      {/* fields with defaultValue={state.values.x} */}
      {(dirty || pending) && (
        <div className="sticky bottom-0 flex justify-end gap-3 border-t bg-white p-3">
          <button type="reset" className="btn-secondary" onClick={() => setDirty(false)}>Discard</button>
          <button type="submit" className="btn-primary" disabled={pending}>{pending ? "Saving..." : "Save changes"}</button>
        </div>
      )}
      {state.message && <p role="status">{state.message}</p>}
    </form>
  );
}
```

Theme preference respecting system default (no flash): store `theme` cookie (`system|light|dark`), render `class`/`data-theme` on `<html>` in the root layout from the cookie; for `system` use CSS `prefers-color-scheme`. (Or `next-themes` with its inline script.)

## Recommended Workflow
1. Inventory settings; delete or replace with defaults where possible.
2. Classify by scope (Me/Workspace/Object) and by role required.
3. Group into sections via card sort or support-ticket analysis; name sections in user terms.
4. Choose save model per section; choose control types.
5. Write labels + descriptions; define defaults (privacy-protective).
6. Implement permission-aware rendering, audit logging, and deep links (`/settings/notifications#mentions`).
7. Test findability (tree test "Where would you turn off weekly emails?") and error/revert paths.

## Patterns
- **Settings shell**: sidebar sections + content; mobile list -> detail.
- **Inherited value with override**: "Workspace default (Weekly) · Override".
- **Notification matrix**: rows events, columns channels (Email, Push, In-app).
- **Sticky save bar** for dirty forms.
- **Read-only for non-admins**: disabled controls with "Only admins can change this".
- **Settings search** / command palette entries.
- **Preview**: live preview for appearance settings.

## Anti-Patterns
- **Mixed save models on one page** — users unsure if saved. Fix: one model per section, clear indicator.
- **Double-negative labels** ("Disable non-notification of...") — Fix: positive, outcome-based.
- **Switches that require Save** — contradicts switch semantics. Fix: checkbox in forms, switch for instant.
- **Junk-drawer "General" section** — Fix: meaningful groups.
- **Silent failure of instant toggles** — Fix: revert + message.
- **Privacy-invasive defaults** (marketing emails, data sharing on) — Fix: opt-in.
- **Burying unsubscribe/cancel** — dark pattern. Fix: prominent, one step.
- **Losing unsaved changes on nav** — Fix: guard + sticky bar.

## Accessibility
- Switch semantics: `role="switch"` + `aria-checked` or native checkbox styled; label associated (4.1.2, 1.3.1).
- Changes on input don't trigger unexpected context changes (3.2.2): instant saves are fine; navigation or major UI changes on toggle are not.
- Status messages for "Saved" (4.1.3); errors identified (3.3.1).
- Group related controls with `fieldset/legend` (notification matrix as a table with headers).

## Responsive Design
- Mobile: section list -> detail page with back; controls full-width; sticky save bar above keyboard safe area.
- Matrices become per-event stacked groups on small screens.

## Performance
- Server-render settings pages; instant toggles send small requests; debounce sliders/text-based preferences.
- Avoid loading all settings sections at once in huge apps; route per section.

## Security
- Authorize every setting change server-side (role checks); don't rely on disabled UI.
- Re-auth for security settings; notify email/password/MFA changes via email.
- Audit log for workspace settings.
- Validate values against allowlists (e.g., enum prefs) to prevent mass-assignment.

## Testing
- Playwright: instant toggle persists after reload; failure reverts with message; explicit save + discard; unsaved guard; non-admin sees read-only.
- Tree tests for settings findability.

## Tooling
- shadcn/ui `Switch`, `Form`; Radix Switch; next-themes; React Hook Form (dirty state) for complex forms; feature-flag tools for rollout of new settings.

## Framework Notes
- **Next.js (App Router)**: nested layout `app/(app)/settings/layout.tsx` for section nav; each section a route; Server Actions with role checks + `revalidatePath`; theme via cookie read in root layout to avoid flash.
- **React (Vite SPA)**: settings routes with loader/query; TanStack Query optimistic mutations for toggles; `useBlocker` for unsaved changes.

## AI Agent Guidance
- Do: decide scope and save model before coding; positive outcome labels with descriptions; server-side authorization; privacy-protective defaults.
- Don't: mix instant and explicit saves; don't add a setting where a default suffices without noting the trade-off; don't use switches inside Save forms.
- Verify: reload persistence, failure revert, keyboard switch operation, non-admin view, unsaved-changes guard.

## Examples
```tsx
// Inherited default with override
<fieldset className="py-4">
  <legend className="font-medium">Digest frequency</legend>
  <p className="text-sm text-neutral-600">Workspace default: Weekly</p>
  <label className="mt-2 block"><input type="radio" name="digest" value="inherit" defaultChecked /> Use workspace default</label>
  <label className="block"><input type="radio" name="digest" value="daily" /> Daily</label>
  <label className="block"><input type="radio" name="digest" value="never" /> Never</label>
</fieldset>
```

## Related Skills
- [information-architecture](../information-architecture/Skill.md) — structuring settings
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — control semantics
- [optimistic-ui](../optimistic-ui/Skill.md) — instant toggles
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — danger zone
- [dark-mode-implementation](../dark-mode-implementation/Skill.md) — theme preference
- [role-based-ui-and-permissions](../role-based-ui-and-permissions/Skill.md) — permission-aware settings
- [progressive-disclosure](../progressive-disclosure/Skill.md) — advanced settings
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — privacy defaults

## Sources
- [NN/g: Toggle-Switch Guidelines](https://www.nngroup.com/articles/toggle-switch-guidelines/) — Community (research) — switch vs checkbox, immediate effect
- [Apple HIG: Settings](https://developer.apple.com/design/human-interface-guidelines/settings) — Official — minimize settings, sensible defaults
- [Microsoft Fluent / Windows app settings guidelines](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings) — Official — grouping, immediate apply
- [Material Design 3: Switch](https://m3.material.io/components/switch/guidelines) — Official — switch usage
- [WAI-ARIA APG: Switch](https://www.w3.org/WAI/ARIA/apg/patterns/switch/) — Official
- [GDPR Art. 25 data protection by design and by default](https://gdpr-info.eu/art-25-gdpr/) — Official (regulation text mirror)

## License / Usage Notes
Summarized; code original.

## Quality Tier
A — consistent guidance across platform HIGs and research; save-model choice requires product judgment.

## Status
Active

## Last Verified
2026-09-15
