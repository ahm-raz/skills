# Buttons and Actions

## Summary
How to build buttons, icon buttons, toggle buttons, button groups, submit buttons, and link-styled actions in React and Next.js that are semantically correct, keyboard-operable, clearly labeled, and resilient to double submission. Covers hierarchy (primary/secondary/tertiary/destructive), pending and disabled states (`useFormStatus`, `useActionState`, React Hook Form `isSubmitting`), `type` semantics inside forms, and the declarative `popoverTarget` / invoker command attributes.

## Category
Components

## Subcategories
buttons, icon buttons, toggle buttons, button groups, split buttons, links vs buttons, submit buttons, pending states, double-submit prevention, invoker commands

## Problem It Solves
Buttons are the most frequently misbuilt control: `<div onClick>` with no keyboard support, icon buttons without names, submit buttons disabled until the form is valid so users can't find out what's wrong, forms submitted by accident because a button has no `type="button"`, double charges from double clicks, and pages with five competing "primary" actions. This skill gives one defensible way to build actions in React/Next.js.

## When To Use
- Any control that does something on the current page: submit, save, open a dialog, toggle, delete.
- Designing a `Button` / `SubmitButton` component API for a design system.
- Reviewing forms for accidental submits, double submits, or confusing disabled states.
- Adding pending feedback to Server Actions or async client handlers.

## When Not To Use
- Going to another URL: use `next/link` `<Link>` or `<a href>`, possibly styled like a button. See [navigation-menus-and-sidebars](../navigation-menus-and-sidebars/Skill.md).
- A menu of actions: use the menu button pattern. See [dropdown-menus](../dropdown-menus/Skill.md).
- A setting that takes effect immediately and has on/off state: consider a switch. See [checkbox-radio-switch](../checkbox-radio-switch/Skill.md).

## Core Principles
1. Buttons act, links navigate. Pick the element by what it does, not how it looks.
2. Use the native `<button>`. It gives you focus, Enter/Space activation, form participation, and the `button` role.
3. Every button has an accessible name that states the action, verb first ("Save draft", "Delete invoice").
4. One primary action per view or region. Show hierarchy with more than color.
5. Always set `type`. Inside a `<form>` the default is `submit`.
6. Keep submit buttons enabled and show validation messages, rather than disabling the button with no reason given.
7. Async actions show a pending state and either are idempotent or ignore repeat clicks.
8. Don't change the label text to show toggle state; use `aria-pressed`.

## Best Practices
- Write labels in sentence case with specific verbs: "Pay 42.00 EUR", "Save and continue". Avoid "OK", "Submit", "Click here".
- Put the primary form action where the eye finishes: bottom-left of a single-column form, lined up with the fields (GOV.UK, Adam Silver). In dialogs, follow one product-wide convention.
- Target size: WCAG 2.2 SC 2.5.8 requires at least 24x24 CSS px (or enough spacing). Aim for 44x44 on touch (`min-h-11`).
- Show a `:focus-visible` ring with at least 3:1 contrast (SC 2.4.7, 1.4.11), and make sure sticky bars don't cover focused elements (SC 2.4.11).
- Destructive actions need their own styling (not just red), an explicit label ("Delete 3 files"), and a confirmation or undo. See [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md).
- Pending state: keep the label or change it to "Saving...", keep the width stable, and announce the result in a `role="status"` region. Don't unmount the button, or focus is lost.
- Guard against double submit on the client (ignore clicks while pending) and on the server (idempotency keys for payments or creates).
- Icon-only buttons need `aria-label` (or visually hidden text) and ideally a tooltip showing the same name. See [tooltips](../tooltips/Skill.md).
- If an action isn't allowed because of permissions, either hide it or show it with an explanation. Don't just disable it silently.

## Implementation Guidance

### Element decision table
| Behavior | TSX | Notes |
|---|---|---|
| Go to a route/URL | `<Link href>` / `<a href>` | Open in new tab and history keep working |
| Submit a form | `<button type="submit">` | Enter in a text field triggers it |
| In-page action | `<button type="button" onClick>` | Inside forms the default is submit |
| Toggle on/off (bold, mute) | `<button type="button" aria-pressed={on}>` | Label stays the same |
| Open a menu | Radix/Base UI `Menu.Trigger` | Handles `aria-haspopup` and `aria-expanded` |
| Open a popover | `<button popoverTarget="id">` | React 19 types `popoverTarget`; `aria-expanded` is managed for you |
| Open a dialog | Controlled `Dialog` primitive, or `commandfor`/`command` | See invoker note below |
| Different endpoint per button | `<button formAction={serverAction}>` | React 19 form actions |

### disabled vs aria-disabled
- `disabled` takes the button out of the tab order and blocks clicks. Screen reader users tabbing through never find it or learn why.
- `aria-disabled="true"` keeps it focusable and announced as dimmed. You must block activation in the handler yourself. Use it for pending states and for "why can't I?" explanations.
- Default for forms: keep submit enabled, validate on submit, and focus the first error or an error summary. See [form-validation-patterns](../form-validation-patterns/Skill.md).

### Pending state sources
| Stack | Source of `pending` |
|---|---|
| Next.js `<form action={serverAction}>` | `useFormStatus().pending`, read in a child component of the `<form>` |
| `useActionState` | Third tuple value: `const [state, action, isPending]` |
| React Hook Form | `formState.isSubmitting` (true while the async `onSubmit` promise runs) |
| Plain async click | `useTransition()` → `isPending` |

`useFormStatus` only reads the status of a parent `<form>`. Calling it in the component that renders the form always returns `pending: false`.

### Invoker commands
`command`/`commandfor` on `<button>` declaratively open/close `<dialog>` (`show-modal`, `close`, `request-close`) and popovers (`toggle-popover`, etc.). Custom commands start with `--`. They shipped in Chromium, Firefox, and Safari during 2025, so re-check your support matrix. If your `@types/react` version doesn't type them, pass them via a spread (`{...{ commandfor: 'id', command: 'show-modal' }}`). In most React apps a controlled dialog primitive is still the better choice, because state stays in React.

## Recommended Workflow
1. List every action in the view and mark each as navigate or act.
2. Assign hierarchy: one primary, secondary alternatives, tertiary for rare actions, and flag destructive ones.
3. Choose elements from the decision table and set `type` on every `<button>`.
4. Write labels (verb + object) and names for icon-only buttons.
5. Define states: default, hover, focus-visible, active, pending, disabled/aria-disabled, pressed.
6. Wire the pending source (table above), the client repeat guard, the server idempotency guard, and error feedback.
7. Check target sizes, contrast, the focus ring, and keyboard use (Tab, Enter, Space).
8. Test with a screen reader, and test Enter-to-submit inside real forms.

## Patterns
- **Polymorphic Button**: one styled component that renders `<button>` or `<Link>` through Radix `Slot` (`asChild`) or the Base UI `render` prop. Each rendered element keeps its own semantics.
- **SubmitButton**: a child component that reads `useFormStatus()` and sets `aria-disabled` plus pending text.
- **Toggle button**: `<button type="button" aria-pressed={on}>Bold</button>`, styled from `aria-pressed:`.
- **Toggle group**: related toggles in `role="group"` with a name. Single-select groups behave like radios (Radix `ToggleGroup type="single"`, React Aria `ToggleButtonGroup`).
- **Split button**: a primary button plus a separate menu button with its own name ("More save options").
- **Toolbar**: many icon buttons get `role="toolbar"`, roving tabindex, and arrow keys (APG Toolbar; Radix/Base UI `Toolbar`).
- **Per-button server action**: `<button formAction={archive}>Archive</button>` next to `<button formAction={remove}>Delete</button>` in the same form.
- **Sticky mobile action bar**: keeps the primary action reachable; add `scroll-padding-bottom` so it doesn't hide focused fields.

## Anti-Patterns
- **`<div onClick>` / `<span role="button">`**: not focusable, no Enter/Space. Fix: `<button type="button">`.
- **No `type` inside a form**: "Show password" or "Add row" submits the form. Fix: `type="button"`.
- **`<a href="#" onClick>` for actions**: breaks middle-click and adds history noise. Fix: `<button>`.
- **`<button onClick={() => router.push('/x')}>` for navigation**: loses link semantics, prefetch, and open-in-new-tab. Fix: `<Link href="/x">`.
- **Submit disabled until the form is valid** (`disabled={!formState.isValid}`): users can't find out what's wrong. Fix: keep it enabled and show errors on submit.
- **`useFormStatus` in the same component as `<form>`**: always false. Fix: move it into a child `SubmitButton`.
- **Icon button with no name**: announced as just "button". Fix: `aria-label`, and `aria-hidden` on the SVG.
- **Label changes and `aria-pressed` together**: sends the state twice. Fix: pick one approach.
- **Spinner replaces the label**: width jumps and the name disappears. Fix: keep the text, add an `aria-hidden` spinner, announce via a status region.
- **Several primary buttons**: weakens the call to action. Fix: demote the others to secondary.
- **`outline: none` with no replacement**. Fix: a `focus-visible:` ring.

## Accessibility
- Role `button` (native). Name comes from content or `aria-label` (SC 4.1.2).
- Keyboard: Enter and Space activate a button; a link activates only on Enter (SC 2.1.1).
- Toggle: `aria-pressed`. Menu trigger: `aria-haspopup`, `aria-expanded`, `aria-controls` (primitives set these).
- SC 2.4.7 Focus Visible, 2.4.11 Focus Not Obscured, 2.5.8 Target Size, 1.4.3 / 1.4.11 contrast.
- SC 2.5.3 Label in Name: the accessible name must contain the visible text, so voice users can say "click Save".
- Safari doesn't focus buttons on click, so don't depend on `document.activeElement` after a click.
- Announce async results with `role="status"`. See [live-regions-and-announcements](../live-regions-and-announcements/Skill.md).

## Responsive Design
- Full-width primary buttons are fine for forms on narrow screens; place them inline on wider screens.
- Stack button groups on small screens without breaking the match between DOM order and visual order (SC 1.3.2, 2.4.3). Avoid `flex-direction: row-reverse` hacks.
- Enlarge hit areas for coarse pointers (`pointer-coarse:` variant in Tailwind v4) or use a pseudo-element hit area.

## Performance
- Update the pending UI first, then do the work. Use `startTransition` or `useActionState` so INP stays low. See [inp-optimization](../inp-optimization/Skill.md).
- Avoid heavy animated spinners (Lottie) inside buttons; a CSS animation is enough.
- A `Button` rendered in large lists shouldn't create new variant objects per render; `cva` is fine, and React Compiler memoizes automatically.

## Security
- Disabling or hiding a button isn't authorization. Check permissions again inside every Server Action or route handler.
- Server Actions are public POST endpoints: validate input with the shared Zod schema and check the session in every action. Next.js compares Origin and Host for actions; configure `serverActions.allowedOrigins` behind proxies.
- Use idempotency keys (or unique constraints) for create/payment actions so a double submit can't duplicate work.
- Never render user-controlled values into `formAction` URLs.
- Protect pages with sensitive actions from clickjacking with `frame-ancestors`. See [content-security-policy](../content-security-policy/Skill.md).

## Testing
- Testing Library: `getByRole('button', { name: /save/i })`; assert `aria-pressed`, `aria-disabled`, and pending text.
- Enter in a text field submits once; `type="button"` buttons never submit (`onSubmit` spy).
- Double click: `await user.dblClick(submit)` should send exactly one request (MSW handler counter).
- Server Actions: unit-test the action function directly with `FormData`, including invalid input and unauthorized cases.
- Playwright: keyboard-only flow, focus ring screenshot, axe rules `button-name` and `target-size`.

## Tooling
- React Aria `Button` (normalized press events, `isPending`), `ToggleButton`, `ToggleButtonGroup`. Active.
- Radix `Slot`, `Toggle`, `ToggleGroup`, `Toolbar`. Active.
- Base UI `Button`, `Toggle`, `ToggleGroup`, `Toolbar` (`@base-ui/react` v1.x). Active.
- shadcn/ui `Button` (cva variants, Radix Slot or Base UI). Active; code is copied into your project.
- `class-variance-authority` / `tailwind-variants` for variant APIs. Active.
- `eslint-plugin-jsx-a11y` (`control-has-associated-label`, `no-static-element-interactions`, `click-events-have-key-events`). Active.

## Framework Notes
- **React (Vite SPA)**: no Server Actions. Use React Hook Form `handleSubmit` + `formState.isSubmitting`, or `useActionState` with a client async function that calls your API (the API validates again with the same Zod schema from a shared package). Use `<Link>` from your router for navigation. In React 19, `ref` is a regular prop, so `forwardRef` isn't needed.
- **Next.js (App Router)**: `<form action={serverAction}>` works before hydration (progressive enhancement). `useFormStatus` gives pending state in children, `useActionState` returns `[state, formAction, isPending]`, and `<button formAction={otherAction}>` sends one form to different actions. Call `redirect()` / `revalidatePath()` inside the action after a successful mutation. `<Link>` prefetches routes, while buttons that navigate don't.

## AI Agent Guidance
- Do: choose `<button>` / `<Link>` by behavior; set `type` on every button; name icon buttons; keep one primary per region; build `SubmitButton` with `useFormStatus` in a child component; keep submit enabled; re-validate in the Server Action.
- Don't: generate `div` buttons, `disabled={!isValid}` submits, `router.push` buttons for navigation, or label swaps together with `aria-pressed`; don't remove focus outlines.
- Verify before done: grep for `onClick` on `div`/`span`; grep for `<button` without `type` inside forms; run axe; tab through and activate with Enter and Space; double-click submit and confirm one mutation; check the pending UI appears with network throttling.

## Examples
```tsx
// components/ui/button.tsx — design-system Button (React 19, Tailwind v4, cva)
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex min-h-11 items-center justify-center gap-2 rounded-md px-4 font-medium ' +
    'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-700 ' +
    'aria-disabled:cursor-not-allowed aria-disabled:opacity-60',
  {
    variants: {
      intent: {
        primary: 'bg-blue-700 text-white hover:bg-blue-800',
        secondary: 'border border-gray-500 bg-white text-gray-900 hover:bg-gray-50',
        danger: 'bg-red-700 text-white hover:bg-red-800',
      },
    },
    defaultVariants: { intent: 'primary' },
  },
);

export type ButtonProps = React.ComponentProps<'button'> &
  VariantProps<typeof buttonVariants> & { asChild?: boolean; pending?: boolean };

export function Button({
  asChild, intent, pending = false, type = 'button', className, children, onClick, ...rest
}: ButtonProps) {
  const Comp = asChild ? Slot : 'button';
  return (
    <Comp
      {...(asChild ? {} : { type })}
      aria-disabled={pending || undefined}
      onClick={(e: React.MouseEvent<HTMLButtonElement>) => {
        if (pending) { e.preventDefault(); return; } // repeat guard, keeps focus
        onClick?.(e);
      }}
      className={buttonVariants({ intent, className })}
      {...rest}
    >
      {pending && (
        <span aria-hidden="true" className="size-4 animate-spin rounded-full border-2 border-current border-r-transparent" />
      )}
      {children}
    </Comp>
  );
}
```

```tsx
// components/ui/submit-button.tsx — for Server Action forms (must be a child of <form>)
'use client';
import { useFormStatus } from 'react-dom';
import { Button, type ButtonProps } from './button';

export function SubmitButton({ children, pendingLabel, ...props }: ButtonProps & { pendingLabel?: string }) {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" pending={pending} {...props}>
      {pending && pendingLabel ? pendingLabel : children}
    </Button>
  );
}
```

```tsx
// app/projects/[id]/rename/schema.ts — ONE schema shared by client and server
import { z } from 'zod';

export const renameProjectSchema = z.object({
  projectId: z.string().min(1),
  name: z.string().trim().min(1, 'Enter a project name').max(80, 'Project name must be 80 characters or fewer'),
  idempotencyKey: z.uuid(),
});
export type RenameProjectInput = z.infer<typeof renameProjectSchema>;
export type RenameProjectState = {
  ok: boolean;
  message?: string;
  errors?: Partial<Record<keyof RenameProjectInput, string[]>>;
  values?: { name?: string };
};
```

```tsx
// app/projects/[id]/rename/actions.ts — server validates again in both paths
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { renameProjectSchema, type RenameProjectState } from './schema';
import { requireUser, renameProject } from '@/lib/server/projects'; // your data layer

async function run(input: unknown): Promise<RenameProjectState> {
  const user = await requireUser();                          // authn/authz on every action
  const parsed = renameProjectSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  }
  await renameProject(user, parsed.data);                    // uses idempotencyKey to dedupe
  revalidatePath(`/projects/${parsed.data.projectId}`);
  return { ok: true, message: 'Project renamed' };
}

// (A) useActionState + FormData
export async function renameProjectAction(_prev: RenameProjectState, formData: FormData): Promise<RenameProjectState> {
  const input = {
    projectId: formData.get('projectId'),
    name: formData.get('name'),
    idempotencyKey: formData.get('idempotencyKey'),
  };
  const result = await run(input);
  return result.ok ? result : { ...result, values: { name: String(input.name ?? '') } };
}

// (B) called directly from React Hook Form with a typed object
export async function renameProject_rhf(input: unknown): Promise<RenameProjectState> {
  return run(input);
}
```

```tsx
// (A) Server Action form: useActionState + useFormStatus (works before hydration)
'use client';
import { useActionState, useId } from 'react';
import { renameProjectAction } from './actions';
import type { RenameProjectState } from './schema';
import { SubmitButton } from '@/components/ui/submit-button';

export function RenameFormAction({ projectId, name }: { projectId: string; name: string }) {
  const [state, formAction] = useActionState<RenameProjectState, FormData>(renameProjectAction, { ok: false });
  const id = useId();
  const error = state.errors?.name?.[0];
  return (
    <form action={formAction} noValidate>
      <input type="hidden" name="projectId" value={projectId} />
      <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
      <label htmlFor={id}>Project name</label>
      {error && <p id={`${id}-error`} className="text-red-700">{error}</p>}
      <input id={id} name="name" defaultValue={state.values?.name ?? name}
        aria-invalid={error ? true : undefined} aria-describedby={error ? `${id}-error` : undefined} />
      <SubmitButton pendingLabel="Saving…">Save name</SubmitButton>
      <p role="status">{state.ok ? state.message : ''}</p>
    </form>
  );
}
```
Note: `crypto.randomUUID()` in render gives a new key on every render. In production, create it once (`useState(() => crypto.randomUUID())`) and rotate it after success.

```tsx
// (B) React Hook Form + Zod on the client, calling the same server function
'use client';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { renameProjectSchema, type RenameProjectInput } from './schema';
import { renameProject_rhf } from './actions';
import { Button } from '@/components/ui/button';

export function RenameFormRHF({ projectId, name }: { projectId: string; name: string }) {
  const [status, setStatus] = useState('');
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm<RenameProjectInput>({
    resolver: zodResolver(renameProjectSchema),
    mode: 'onSubmit',
    defaultValues: { projectId, name, idempotencyKey: crypto.randomUUID() },
  });

  const onSubmit = handleSubmit(async (values) => {
    const res = await renameProject_rhf(values);       // server re-validates
    if (!res.ok) {
      const msg = res.errors?.name?.[0];
      if (msg) setError('name', { message: msg }, { shouldFocus: true });
      return;
    }
    setStatus(res.message ?? 'Saved');
  });

  return (
    <form onSubmit={onSubmit} noValidate>
      <label htmlFor="name">Project name</label>
      {errors.name && <p id="name-error" className="text-red-700">{errors.name.message}</p>}
      <input id="name" {...register('name')} aria-invalid={errors.name ? true : undefined}
        aria-describedby={errors.name ? 'name-error' : undefined} />
      <Button type="submit" pending={isSubmitting}>{isSubmitting ? 'Saving…' : 'Save name'}</Button>
      <p role="status">{status}</p>
    </form>
  );
}
```

```tsx
// Icon button, toggle button, and a declarative popover
import { useState } from 'react';
import { XIcon } from 'lucide-react';

export function ToolbarBits() {
  const [bold, setBold] = useState(false);
  return (
    <>
      <button type="button" aria-label="Close">
        <XIcon aria-hidden="true" focusable="false" />
      </button>
      <button type="button" aria-pressed={bold} onClick={() => setBold((b) => !b)}>Bold</button>
      <button type="button" popoverTarget="help">Help</button>
      <div id="help" popover="auto">Keyboard shortcuts…</div>
    </>
  );
}
```

## Related Skills
- [form-design-ux](../form-design-ux/Skill.md) — where actions go in a form
- [form-validation-patterns](../form-validation-patterns/Skill.md) — why submit shouldn't be disabled
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — client form state and shared schemas
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security and revalidation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState, useFormStatus, transitions
- [progressive-enhancement](../progressive-enhancement/Skill.md) — forms that work before hydration
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — delete flows
- [dropdown-menus](../dropdown-menus/Skill.md) — menu and split buttons
- [accessible-dialogs](../accessible-dialogs/Skill.md) — dialog triggers and returning focus
- [component-api-design](../component-api-design/Skill.md) — variant and polymorphic APIs
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — target sizes

## Sources
- [MDN: The Button element](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button) — Official — type default, command/commandfor, popovertarget, formaction, a11y notes
- [WAI-ARIA APG: Button Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/button/) — Official — keyboard, `aria-pressed`, constant labels
- [GOV.UK Design System: Button](https://design-system.service.gov.uk/components/button/) — Official — hierarchy, disabled-button advice, double-click prevention, button text
- [WCAG 2.2 Understanding 2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) — Official — 24px minimum
- [React docs: useFormStatus / useActionState](https://react.dev/reference/react-dom/hooks/useFormStatus) — Official — pending semantics, child-component requirement
- [Next.js docs: Forms and Server Actions](https://nextjs.org/docs/app/guides/forms) — Official — form actions, validation, pending UI
- [React Aria Button](https://react-aria.adobe.com/Button) — Open Source — press events, isPending
- [Radix Primitives](https://www.radix-ui.com/primitives) — Open Source — Slot/asChild, Toggle, ToggleGroup
- [web.dev: Sign-in form best practices](https://web.dev/articles/sign-in-form-best-practices) — Official — submit button practices

## License / Usage Notes
Guidance is summarized in original words from W3C (W3C Document License), MDN (CC-BY-SA 2.5), GOV.UK Design System (MIT / OGL), React and Next.js docs (CC-BY 4.0 / MIT). All code examples are original. Radix (MIT), cva (Apache-2.0), React Aria (Apache-2.0), React Hook Form (MIT), Zod (MIT).

## Quality Tier
A — grounded in APG, WCAG 2.2, MDN, GOV.UK, and React/Next.js docs; cross-browser support for invoker commands should be re-checked per project.

## Status
Active

## Last Verified
2026-09-15
