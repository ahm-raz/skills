# Small UI Primitives: Vaul, Sonner, cmdk

## Summary
Three focused React libraries became de facto standards through shadcn/ui: **Sonner** (toasts, `sonner` 2.0.8, MIT, Emil Kowalski), **cmdk** (command menu / filterable combobox, `cmdk` 1.1.1, MIT, Paco Coursey) and **Vaul** (drawer/bottom sheet, `vaul` 1.1.2, MIT). As of September 2026, **Vaul is officially unmaintained** (since October 2025), so new work should use Base UI's Drawer, which is what shadcn's Drawer now uses. Sonner remains widely used, with a Base UI Toast as a newer alternative in shadcn (July 2026). cmdk still works but depends on Radix Dialog internals and has seen few recent releases.

## Category
UI Libraries

## Subcategories
Toasts, command palette, drawers/bottom sheets, maintenance risk, shadcn integrations, Base UI Drawer/Toast replacements

## Problem It Solves
It helps you choose and correctly use small single-purpose libraries for common interaction patterns, while avoiding abandoned packages and knowing the maintained replacements.

## When To Use
- Sonner: app-wide toasts with promise states, actions and stacking with minimal setup.
- cmdk: Cmd+K command palettes and filterable lists up to ~2-3k items.
- Vaul: only in existing code. Plan a migration to Base UI Drawer.

## When Not To Use
- Vaul in new projects (unmaintained). Use Base UI Drawer (or shadcn Drawer on Base UI).
- cmdk for very large or remote datasets without virtualization, or when you need a full combobox with form semantics. Use Base UI Combobox, React Aria ComboBox or Ariakit.
- Toasts for critical errors requiring action or persistence. Use inline errors or dialogs.

## Core Principles
1. **Check maintenance before adopting "tiny" packages**: small libraries often have single maintainers.
2. **Toasts are transient, polite announcements**: never the only place for important information.
3. **Command menus are search plus actions**: fast filtering, keyboard-first, grouped results, empty state.
4. **Sheets on mobile need gesture and keyboard parity**: swipe to dismiss plus Escape plus a close button.
5. **Prefer the primitive layer your design system uses** (Base UI, Radix or React Aria) to avoid duplicated overlay stacks.

## Best Practices
- **Sonner**: mount one `<Toaster />` at the root layout. Call `toast()` anywhere (outside React too). Use `toast.promise(p, { loading, success, error })` for async work. Set `richColors`/`closeButton` per design. Keep messages short and actionable.
- **cmdk**: use `Command.Dialog` for Cmd+K overlays. Provide `Command.Empty`. Set `shouldFilter={false}` when filtering on the server and render results yourself. Use `value` keywords for better matching. Keep < ~2-3k items or virtualize.
- **Vaul to Base UI Drawer**: map `direction` to `swipeDirection` and `asChild` to `render` (shadcn's documented migration). Add `Drawer.VirtualKeyboardProvider` for forms in drawers.
- **Base UI Toast (shadcn, July 2026)**: supports actions, status types, promises, stacking and swipe dismissal. Consider it when your project is on the Base UI base to reduce dependencies.
- Register global keyboard shortcuts carefully (`metaKey || ctrlKey` + `k`), ignoring events while typing in inputs where appropriate.

## Implementation Guidance
| Need | Recommended (September 2026) | Notes |
|---|---|---|
| Toasts | Sonner 2.x or Base UI Toast | Sonner simplest; Base UI Toast aligns with Base UI projects |
| Command palette | cmdk 1.1.1 (small lists) or Base UI/React Aria Autocomplete/Combobox | cmdk depends on `@radix-ui/react-dialog` |
| Drawer / bottom sheet | Base UI Drawer (shadcn Drawer) | Vaul unmaintained |
| Existing Vaul code | Keep working; schedule migration | Pin version |

Dependencies to know:
- `cmdk` 1.1.1 pulls `@radix-ui/react-dialog`, `react-id`, `react-primitive` and `react-compose-refs` (peers React 18/19).
- `vaul` 1.1.2 depends on `@radix-ui/react-dialog`.
- `sonner` 2.0.8 peers React 18/19 with no Radix dependency.

## Recommended Workflow
1. Inventory usage: `grep` for `vaul`, `sonner`, `cmdk` imports.
2. For Vaul, migrate drawers one by one to Base UI Drawer. Test swipe, Escape, focus return and the virtual keyboard.
3. For toasts, standardize one API (Sonner or Base UI Toast) and a wrapper (`notify.success()`) to allow a later swap.
4. For command menus, define the command registry (id, label, keywords, action, group) separately from UI.
5. Verify a11y (live region announcements, dialog semantics) and mobile behavior.

## Patterns
- **Notification facade**: `lib/notify.ts` wraps the toast library so swapping Sonner for Base UI Toast is a one-file change.
- **Server action feedback**: `toast.promise(saveAction(formData), {...})` in a client handler, with an inline form error for validation failures.
- **Command registry**: `commands: Command[]` built from routes and permissions, rendered by cmdk groups. Actions call `router.push` or mutations.
- **Responsive overlay**: Dialog on `md+`, Drawer on mobile via `useMediaQuery`, sharing the same content component.

## Anti-Patterns
- **Starting new drawers on Vaul**: unmaintained, and bugs won't be fixed.
- **Toasts for form validation errors**: users lose context. Use inline field errors.
- **Multiple `<Toaster />` instances**: duplicate toasts and stacking bugs.
- **cmdk with 20k client-side items**: janky filtering. Filter on the server with `shouldFilter={false}` or virtualize.
- **Mixing Radix Dialog (via cmdk/Vaul) with Base UI overlays without testing stacking**: focus-trap conflicts. Test nested overlays.

## Accessibility
- Toasts: announced via live regions (polite). Don't auto-dismiss toasts that contain actions too quickly (WCAG 2.2.1). Provide a pause on hover/focus and ensure actions are keyboard reachable.
- cmdk: combobox/listbox semantics with `aria-activedescendant`. `Command.Dialog` needs an accessible label (`label` prop). Ensure a visible focus/selection style.
- Drawers: dialog semantics, focus trap, Escape, a visible close button (not swipe-only, WCAG 2.5.1 pointer gestures alternatives).
- Respect reduced motion for sheet and toast animations.

## Responsive Design
- Sonner `position` (e.g. `top-center` on mobile, `bottom-right` on desktop). Avoid covering primary actions and bottom nav.
- Drawers: snap points and max heights for small screens. Account for the on-screen keyboard (VirtualKeyboardProvider).
- Command palette: full-screen on mobile, centered modal on desktop.

## Performance
- Sonner is small. Lazy import is rarely necessary.
- cmdk filters in memory. Debounce server queries. Keep item render cheap.
- Drawers: lazy-mount content. Avoid heavy components inside closed sheets.

## Security
- Never render untrusted HTML in toast descriptions. Pass text or safe JSX.
- Command palettes that expose admin actions must enforce authorization server-side. Hiding commands is UX, not security.
- Pin versions. Unmaintained packages (Vaul) won't receive security fixes, so migrate.

## Testing
- Toasts: assert `findByText` after the action and the live region role (`status`). Use fake timers for dismissal.
- cmdk: type into `combobox`, assert `option` filtering, Enter triggers the action.
- Drawers: Playwright for swipe gestures and virtual-keyboard layouts (mobile emulation).

## Tooling
- `sonner` 2.0.8 (MIT), `cmdk` 1.1.1 (MIT), `vaul` 1.1.2 (MIT, unmaintained), `@base-ui/react` (Drawer, Toast), shadcn `drawer`/`toast`/`sonner`/`command` components.
- Emil Kowalski's agent skills (e.g. `/pick-ui-library`, `/ask-sonner`) list trusted small libraries. Treat them as community guidance.

## Framework Notes
- **Next.js App Router**: `<Toaster />` goes in a client component rendered from `app/layout.tsx` (Sonner's Toaster is a client component). Call `toast()` only in client code (event handlers, effects), not in Server Components or server actions. Return a result and toast on the client. cmdk and drawers are client components. Register Cmd+K listeners in a client provider.
- **React (Vite SPA)**: mount the Toaster in the root component. The same patterns apply.
- React 19: sonner and cmdk peers include 19. Vaul peers include 19 but it is unmaintained.

## AI Agent Guidance
- DO check `package.json` for `vaul` and recommend Base UI Drawer for new drawers. Don't add Vaul.
- DO reuse the project's existing toast system and wrapper. Don't add a second toast library.
- DO give `Command.Dialog` a label and an empty state.
- DON'T call `toast()` from server code.
- Verify before done: one Toaster, drawers keyboard- and swipe-dismissable with a close button, command palette works by keyboard only, no new dependency on unmaintained packages.

## Examples
```tsx
// app/providers.tsx
"use client";
import { Toaster } from "sonner";
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      <Toaster position="bottom-right" closeButton richColors />
    </>
  );
}
```
```tsx
// Save with promise toast (client)
"use client";
import { toast } from "sonner";
import { saveProfile } from "./actions"; // server action returning { ok: boolean; error?: string }

export function SaveButton({ data }: { data: FormData }) {
  return (
    <button
      onClick={() =>
        toast.promise(
          saveProfile(data).then((r) => { if (!r.ok) throw new Error(r.error ?? "Save failed"); return r; }),
          { loading: "Saving…", success: "Profile saved", error: (e: Error) => e.message },
        )
      }
    >
      Save
    </button>
  );
}
```
```tsx
// Command palette with cmdk
"use client";
import { Command } from "cmdk";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type Cmd = { id: string; label: string; group: string; href: string; keywords?: string[] };

export function CommandPalette({ commands }: { commands: Cmd[] }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "k" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); setOpen((o) => !o); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  const groups = [...new Set(commands.map((c) => c.group))];
  return (
    <Command.Dialog open={open} onOpenChange={setOpen} label="Command menu" className="fixed inset-x-0 top-24 mx-auto w-full max-w-lg rounded-lg border bg-popover">
      <Command.Input placeholder="Type a command or search…" className="w-full border-b px-3 py-2" />
      <Command.List className="max-h-80 overflow-auto p-1">
        <Command.Empty className="p-3 text-sm">No results.</Command.Empty>
        {groups.map((g) => (
          <Command.Group key={g} heading={g}>
            {commands.filter((c) => c.group === g).map((c) => (
              <Command.Item key={c.id} value={c.label} keywords={c.keywords} onSelect={() => { setOpen(false); router.push(c.href); }}
                className="rounded px-2 py-1.5 data-[selected=true]:bg-muted">
                {c.label}
              </Command.Item>
            ))}
          </Command.Group>
        ))}
      </Command.List>
    </Command.Dialog>
  );
}
```

## Related Skills
- [toasts-and-notifications](../toasts-and-notifications/Skill.md): toast UX
- [command-palette](../command-palette/Skill.md): palette UX
- [drawers-and-sheets](../drawers-and-sheets/Skill.md): sheet patterns
- [base-ui](../base-ui/Skill.md): Drawer/Toast replacements
- [shadcn-ui](../shadcn-ui/Skill.md): integrations
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md): toast announcements
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md): unmaintained package risk

## Sources
- [emilkowalski/vaul](https://github.com/emilkowalski/vaul): Open Source. Unmaintained notice
- [shadcn issue #8455: switch drawer to maintained dependency](https://github.com/shadcn-ui/ui/issues/8455): Open Source. Vaul unmaintained since October 2025
- [shadcn Drawer (Base UI)](https://ui.shadcn.com/docs/components/base/drawer): Official. Drawer now on Base UI; prop mapping
- [shadcn Toast (July 2026)](https://ui.shadcn.com/docs/changelog/2026-07-toast): Official. Base UI Toast features
- [emilkowalski/sonner](https://github.com/emilkowalski/sonner): Open Source. API, MIT
- [pacocoursey/cmdk](https://github.com/pacocoursey/cmdk): Open Source. API, Radix Dialog dependency, performance guidance
- npm registry metadata for [vaul](https://registry.npmjs.org/vaul/latest), [sonner](https://registry.npmjs.org/sonner/latest), [cmdk](https://registry.npmjs.org/cmdk/latest): Official. Versions and dependencies
- [Base UI releases](https://base-ui.com/react/overview/releases): Official. Drawer.VirtualKeyboardProvider, Toast updates

## License / Usage Notes
Sonner, cmdk and Vaul are MIT. Base UI is MIT. Summarized content; examples are original.

## Quality Tier
A: maintenance status, versions, dependencies and replacement paths verified from primary sources.

## Status
Active (Vaul portion: Deprecated/unmaintained)

## Last Verified
2026-09-15
