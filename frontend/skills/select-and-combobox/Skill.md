# Select and Combobox

## Summary
How to build choose-one or choose-many controls from a fixed set of options: the native `<select>`, the new customizable select (`appearance: base-select`), a custom select-only combobox, and an editable (filterable) combobox. Covers picking the right control, WAI-ARIA combobox and listbox semantics, keyboard support, async option loading, multi-select, mobile behavior, and form integration. Free-text search suggestions are in `search-and-autocomplete`. Creating new tags as you type is in `tags-and-chips-input`.

## Category
Components

## Subcategories
Forms, native select, customizable select, combobox, listbox, typeahead, multi-select, ARIA 1.2, headless UI

## Problem It Solves
Custom dropdowns are among the most common sources of accessibility bugs: missing roles, focus that jumps into the list, no typeahead, broken zoom, form values that never get submitted, and unusable touch behavior. Teams also reach for a heavy custom combobox when a native `<select>` or radio group would work better. This skill gives rules for choosing a control and implementing it so it is correct for keyboard, screen reader, touch, and form submission.

## When To Use
- The user must pick one value (or several) from a known, bounded set of options.
- The list is too long for radios (roughly more than 5–7 options), or space is tight.
- The list is long (dozens to thousands of options) and users know what they are looking for, so a filterable combobox fits.
- Options need rich rendering (icon, secondary text) and native select styling is not enough.
- Options come from a server (an entity picker such as users, customers, or SKUs).

## When Not To Use
- 2–5 mutually exclusive options that should all be visible: use radio buttons or a segmented control (see `checkbox-radio-switch`).
- Several choices from a short list: use a checkbox group, not a multi-select listbox.
- Free-text entry where suggestions are optional (site search, address lookup): use `search-and-autocomplete`.
- A list of actions ("Edit, Duplicate, Delete"): that is a menu (`dropdown-menus`), not a select.
- Global navigation or command execution: use `command-palette`.
- Values users know by heart (country of birth for a GOV.UK-style form, or a year): consider a text input with validation. Well-known formats like dates and numbers belong in `date-pickers-and-calendars` and `number-and-currency-inputs`.

## Core Principles
1. **Native first.** A `<select>` gives you platform pickers on mobile, full AT support, autofill, and form submission for free. Only move away from it for a concrete requirement: filtering, rich options, async data, or styling that `base-select` cannot deliver.
2. **A select is not a menu.** A select sets a value (`role="combobox"` + `listbox`/`option`). A menu triggers actions (`menu`/`menuitem`). Mixing them confuses AT.
3. **DOM focus stays on the combobox.** For listbox popups, focus remains on the input or trigger, and the highlighted option is conveyed with `aria-activedescendant` (APG). Only dialog-type popups move real focus.
4. **The value must reach the form.** Custom widgets must submit a value: a hidden input, or a hidden native select as Radix does. They must also honor `name`, `required`, `disabled`, and form reset.
5. **Options are plain text to AT.** The listbox pattern cannot expose interactive children (links, buttons, checkboxes) inside options. Keep option names short and put the distinguishing text first.
6. **Filtering is a promise.** If users type, show matches fast, show an explicit empty state, and never silently throw away what they typed on blur unless the design says so.

## Best Practices
- Pick the control with the decision table below. Don't default to a combobox.
- Always render a visible `<label>`. Placeholder text is not a label. A select-only combobox's accessible name comes from the label, and its value is its text content.
- Avoid a "Select…" placeholder as a real option unless the field is optional. If you use it, give it `value=""` and `disabled hidden` in native select so `required` validation works.
- Sort options in a meaningful order: alphabetical, by frequency, or with popular options first behind a separator. Put "Other" last.
- Use `<optgroup>` (native) or group/group-label parts (headless libraries) for more than about 15 options that fall into categories.
- For long lists, a filterable combobox beats scrolling. Match on "contains" (not just "starts with") and on synonyms or aliases ("UK" → "United Kingdom"). Highlight the matched substring.
- Show an explicit "No results for 'xyz'" row. Don't render an empty popup or close it silently.
- Async options: debounce input by 150–300 ms, abort stale requests, show a loading row inside the popup, and cache results per query.
- Multi-select comboboxes: show the selections as removable chips next to the input. Keep the popup open after each pick (the reverse of single-select). Announce the selection count.
- Match the popup to the trigger's width at minimum. Let it flip or shift inside the viewport (see `floating-element-positioning`).
- Set touch targets to 44×44 CSS px or larger (WCAG 2.5.8 requires at least 24×24).
- Keep the closed trigger showing the selected label, not the raw id.

## Implementation Guidance

### Decision table
| Need | Use |
|---|---|
| ≤5 options, all worth seeing | Radio group / segmented control |
| 6–~15 options, no styling constraints | Native `<select>` |
| Branded look, simple text or icon options, progressive enhancement OK | `<select>` + `appearance: base-select` (falls back to native) |
| Custom look needed in all browsers today, no filtering | Headless Select (React Aria `Select`, Radix `Select`, Base UI `Select`) |
| Long list (>~15) or users know the answer | Editable combobox with filtering |
| Server-backed entity search | Async combobox (debounce + abort + loading/empty states) |
| Several values from a long list | Multi-select combobox with chips |
| Several values from a short list | Checkbox group |

### Customizable select (progressive enhancement)
As of Sept 2026, `appearance: base-select` is stable in Chromium (Chrome/Edge 135+). Safari has it in Technology Preview / Safari 27 builds, and Firefox has it behind a flag. It is **not Baseline**. Browsers without support ignore the extra markup and render a normal native select, so it is safe to ship as an enhancement.

```tsx
// app/components/pet-select.tsx — Server Component friendly (no client JS needed)
// Styles in app/globals.css:
//   .pet-select, .pet-select::picker(select) { appearance: base-select; }
//   .pet-select::picker-icon { transition: rotate .2s; }
//   .pet-select:open::picker-icon { rotate: 180deg; }
//   .pet-select option:checked { font-weight: 600; }
//   .pet-select option::checkmark { color: var(--accent); }
//   .pet-select::picker(select) { border-radius: 8px; box-shadow: var(--shadow-lg); }
import {createElement} from 'react';

export function PetSelect({defaultValue = ''}: {defaultValue?: string}) {
  return (
    <>
      <label htmlFor="pet">Pet</label>
      <select id="pet" name="pet" required defaultValue={defaultValue} className="pet-select">
        <button type="button">
          {/* React's typings don't know <selectedcontent> yet, so createElement sidesteps JSX type errors */}
          {createElement('selectedcontent')}
        </button>
        <option value="" disabled hidden>Choose a pet</option>
        <option value="cat"><span aria-hidden="true">🐱</span> Cat</option>
        <option value="dog"><span aria-hidden="true">🐶</span> Dog</option>
      </select>
    </>
  );
}
```
Notes: `<button>` inside the select is inert (no interactive children). The picker is a popover anchored to the select, so you can animate it with `@starting-style`. React/Next.js caveats: React may warn about `<button>` or `<span>` inside `<select>`/`<option>`, and older React DOM versions flatten option children to text. Unsupported browsers or hydration paths drop rich option content to plain text. Verify on your React version and check the console for hydration warnings before relying on it, and fall back to a headless Select if the warnings can't be resolved.

### ARIA contract for a custom combobox (APG)
| Element | Attributes |
|---|---|
| Input / trigger | `role="combobox"`, `aria-expanded`, `aria-controls="<listbox id>"`, `aria-activedescendant="<option id>"` (only while an option is highlighted), `aria-autocomplete="list"` (editable with filtering), `none`, or `both` (inline completion) |
| Popup | `role="listbox"`, `id`, optional `aria-label`/`aria-labelledby`; `aria-multiselectable="true"` for multi |
| Option | `role="option"`, unique `id`, `aria-selected="true"` on the selected one(s); `aria-disabled` for disabled |
| Group | `role="group"` + `aria-labelledby` pointing at a presentational heading |
| Non-listbox popup | `aria-haspopup="grid" / "tree" / "dialog"` |

### Keyboard (APG combobox + listbox)
| Key | Closed | Open |
|---|---|---|
| Down Arrow | Open; highlight selected or first option | Next option |
| Up Arrow | (Optional) open; highlight last | Previous option |
| Alt+Down | Open without moving highlight | — |
| Alt+Up | — | Close, keep focus on combobox |
| Enter | (Select-only) open | Commit highlighted option, close |
| Space | (Select-only) open | (Select-only) commit; (editable) types a space |
| Escape | (Optional) clear input | Close; restore previous input text if uncommitted |
| Home / End | (Editable) move caret | First/last option (select-only); caret (editable) |
| Printable chars | Select-only: typeahead jumps to match; editable: type & filter | Same |
| Tab | Move on | Commit highlighted (common convention) and move on; do not trap |
| Multi (listbox) | — | Space toggles; Shift+Arrow extends; Ctrl/Cmd+A selects all |

### Async combobox flow
1. `onInputChange` → update the query state right away so the input stays responsive.
2. Debounce the fetch (about 200 ms). Create an `AbortController` per request and abort the previous one.
3. Render popup rows in this priority: loading row → error row with retry → "No results" row → options.
4. Announce the result count politely ("12 results available") through the library's status or live region. Don't announce every keystroke.
5. On commit, store the **id** as the value and the label as the input text. Rehydrate the label from the id on edit screens.

## Recommended Workflow
1. Inventory the data: how many options, whether it is static or async, whether it is single or multi, whether custom values are allowed.
2. Choose the control from the decision table. Record why native select was rejected, if it was.
3. Pick a headless primitive (React Aria, Base UI, Radix Select, or Downshift). Don't hand-roll ARIA.
4. Wire form integration: `name`, `required`, default value, reset, and schema validation (see `react-hook-form-and-zod`).
5. Implement states: default, hover, focus-visible, open, highlighted option, selected, disabled, invalid, loading, empty, error.
6. Style it: popup positioning, max-height with scroll, flip on overflow, and a mobile full-screen or tray variant if the list is long.
7. Test with keyboard only, then with VoiceOver (macOS and iOS) and NVDA. Test at 200% and 400% zoom.
8. Add unit tests for filtering and value mapping, plus an E2E test of the full keyboard flow.

## Patterns
- **Select-only combobox ("custom select").** Button-like trigger with `role="combobox"`, listbox popup, typeahead. Examples: Radix `Select`, React Aria `Select`, Base UI `Select`.
- **Editable combobox with list filtering.** `aria-autocomplete="list"`. The value must match an option, and input that doesn't match reverts on blur. Examples: React Aria `ComboBox`, Base UI `Combobox`.
- **Creatable combobox.** Adds a last row, `Create "xyz"`, when nothing matches exactly. Requires `allowsCustomValue` or equivalent.
- **Multi-select with chips.** Base UI `Combobox` with `multiple` + `Chips`/`Chip`; React Aria `ComboBox selectionMode="multiple"`; Downshift `useCombobox` + `useTagGroup`.
- **Searchable select in a popover (shadcn "Combobox" recipe).** A trigger button opens a popover that contains a search input and a list. The popover's input becomes the combobox. Keep focus in it and return focus to the trigger when it closes.
- **Enhanced native select.** Server-render a `<select>`, then enhance it on the client (GOV.UK `accessible-autocomplete` `enhanceSelectElement`). No-JS users keep a working form.
- **Virtualized options.** For more than about 1,000 items, virtualize the list (Base UI `virtualized`, React Aria virtualizer, TanStack Virtual). `aria-activedescendant` must point to a rendered node, so scroll the highlighted item into the rendered window first.

```tsx
// React Aria Components — accessible async-friendly combobox
import {ComboBox, Label, Input, Button, Popover, ListBox, ListBoxItem, FieldError} from 'react-aria-components';

export function CountryField({countries}: {countries: {id: string; name: string}[]}) {
  return (
    <ComboBox name="country" isRequired menuTrigger="focus" defaultItems={countries}>
      <Label>Country</Label>
      <div className="field">
        <Input />
        <Button aria-label="Show countries">▾</Button>
      </div>
      <FieldError />
      <Popover>
        <ListBox renderEmptyState={() => 'No countries match'}>
          {(c) => <ListBoxItem id={c.id}>{c.name}</ListBoxItem>}
        </ListBox>
      </Popover>
    </ComboBox>
  );
}
```

## Anti-Patterns
| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| `<div onClick>` dropdown with no roles | Invisible to AT, no keyboard support | Native select or headless primitive |
| Moving DOM focus into each option | Input loses caret, screen readers re-announce the field, and typing breaks | Keep focus on the combobox and use `aria-activedescendant` |
| Using `role="menu"` for a value picker | AT announces actions, not a choice; selection state is lost | `listbox`/`option` with `aria-selected` |
| Buttons or links inside options (e.g. "edit" icon) | Listbox can't expose nested interactive elements | Put secondary actions outside the list, or use a grid pattern |
| Select for 2–3 options | Hides options and costs extra clicks | Radios / segmented control |
| Filtering only by `startsWith` | "States" won't match "United States" | Contains matching + aliases |
| Clearing the typed query on blur without warning | Silent data loss | Revert to the last committed value visibly, or keep the text and show an invalid state |
| No empty or loading row | Users think it's broken | Explicit rows for loading, error, and empty states |
| `<datalist>` as a "combobox" for important data | Options don't scale with zoom, AT support is inconsistent, can't be styled | Use a real combobox. Keep datalist for optional hints only |
| Custom select that doesn't submit | Silent form data loss | Hidden input/select + `name`; test native form submit |
| Opening the popup on every focus for long async lists | Fires requests and noise on Tab-through | `menuTrigger="input"` or open on Arrow/click |
| Race conditions in async search | Old responses overwrite new ones | AbortController + request ids |

## Accessibility
- **WCAG 1.3.1 / 4.1.2**: correct roles, name, state (`aria-expanded`, `aria-selected`), and value.
- **2.1.1 Keyboard / 2.1.2 No Keyboard Trap**: the full APG table above. Tab must leave the widget.
- **2.4.7 / 2.4.11 Focus visible and not obscured**: the highlighted option needs a visible indicator that doesn't rely on color alone (1.4.11 non-text contrast ≥3:1).
- **1.4.4 / 1.4.10 Resize and reflow**: the popup must scale with zoom and stay within the viewport at 320 CSS px.
- **3.3.1 / 3.3.2**: a visible label, an error message associated with `aria-describedby`, and `aria-invalid` on the combobox.
- **4.1.3 Status messages**: announce result counts and "no results" through a polite live region (built into React Aria and GOV.UK accessible-autocomplete).
- **2.5.8 Target size**: options and clear buttons ≥24×24 px (aim for 44).
- iOS VoiceOver has historically handled `aria-activedescendant` poorly. Test on a real device. Mature libraries add workarounds (live announcements of the focused option).
- Don't put `aria-label` on the combobox if a visible label exists. Use `<label for>` or `aria-labelledby`.

## Responsive Design
- On small screens, long or filterable lists work better as a full-screen sheet or tray with a sticky search input (the React Spectrum pattern). Short lists can stay a native select, whose OS wheel or sheet picker is excellent on mobile.
- Keep the popup's max-height inside the visual viewport. The on-screen keyboard shrinks it, so use `dvh` or the VisualViewport API, or let the positioning library handle it.
- Use `inputmode`/`enterkeyhint="search"` or `"done"` for editable comboboxes. Turn off `autocorrect`/`autocapitalize` for code-like values.
- Don't rely on hover to reveal option details.

## Performance
- Virtualize above roughly 500–1,000 options. Rendering thousands of DOM options hurts INP.
- Keep filtering cheap: precompute normalized labels (lowercase, diacritics stripped with `Intl.Collator` or `normalize('NFD')`). Use `useDeferredValue` or a transition for heavy list re-renders.
- Async: debounce, abort, cache by query, prefetch popular options on focus.
- Lazy-load the popup contents or library chunk if the combobox is below the fold.

## Security
- Treat option labels from APIs as untrusted text. Render as text, never as `innerHTML` (highlighted-match rendering is a common XSS vector; split strings instead).
- Validate the submitted value on the server against the allowed set. Client-side option lists are not authorization.
- Async entity search must enforce authorization and rate limiting server-side. Don't leak other tenants' records through suggestions.

## Testing
- Unit/component (Testing Library + user-event): typing filters, ArrowDown/Enter commit, Escape reverts, value submitted in `FormData`, `required` blocks submit, reset restores the default.
- Query by role: `getByRole('combobox', {name: 'Country'})`, `getAllByRole('option')`. Assert `aria-expanded` and `aria-activedescendant`.
- Async: mock with MSW. Assert the loading row, abort of stale requests (only the last response is shown), and the empty state.
- E2E (Playwright): keyboard-only flow, mobile viewport tray, zoom to 200%.
- Automated a11y: axe-core. It catches missing names and roles but not keyboard behavior. Do a manual NVDA + VoiceOver pass.

## Tooling
| Tool | Notes (Sept 2026) |
|---|---|
| Native `<select>` + `appearance: base-select` | Stable in Chromium 135+, Safari TP/27, Firefox behind a flag; progressive enhancement |
| React Aria Components (`Select`, `ComboBox`, `Autocomplete`) | Most thorough AT/mobile handling; ComboBox supports `selectionMode="multiple"`, `allowsCustomValue`, `menuTrigger` |
| Base UI (`Select`, `Combobox`, `Autocomplete`) | v1.x (1.8 at time of writing); Combobox has `multiple`, `Chips`, `virtualized`, `filter`, `autoHighlight`; Autocomplete for free text |
| Radix `Select` | Select-only (no filtering); `item-aligned` or `popper` positioning; hidden native select for forms |
| shadcn/ui Combobox/Select | Copy-in recipes over Radix or Base UI (CLI v4 `--base` flag) |
| Downshift (`useSelect`, `useCombobox`, `useTagGroup`) | Headless hooks, ARIA 1.2 since v7; you own the rendering |
| GOV.UK `accessible-autocomplete` | Vanilla JS, progressive enhancement of `<select>`; minimal maintenance |
| Headless UI `Combobox`/`Listbox`, Ariakit `Combobox`/`Select` | Solid alternatives |
| TanStack Virtual | Virtualizing very large option lists |

## Framework Notes
- **React (Vite SPA)**: headless selects and comboboxes render entirely on the client. Load async options with TanStack Query (query key includes the search text, `signal` passed to `fetch`). With React Hook Form, wrap the widget in `Controller` and store the option **id**. Submit JSON to your API and validate again on the server with the same Zod schema from a shared module.
- **Next.js App Router**: comboboxes are Client Components (`'use client'`). Fetch static or initial options in a Server Component and pass them as props. For async option search, use a cacheable GET Route Handler, not a Server Action. Server Actions are POST, run one at a time, and are not meant for data fetching.
- **Next.js Server Actions**: a custom widget must render a named hidden input (or use the library's `name` support) so `formData.get('country')` works. The action must re-validate with the shared schema and return field errors through `useActionState`.
- **Progressive enhancement**: only a native `<select>` works before hydration or without JS. Where that matters (checkout, government-style services), render native select (optionally with `base-select`) from a Server Component and enhance later.
- React 19 resets uncontrolled form fields after a successful action. Custom widgets that keep their own state need a `key` or explicit reset to match.

## AI Agent Guidance
- Do: start from the decision table and justify any non-native choice in the PR description.
- Do: use an established headless primitive already in the repo. Check `package.json` before adding another.
- Do: make sure the value is submitted (inspect `FormData`) and that `required`/invalid states render an associated error.
- Do: implement loading, empty, and error rows for async sources, plus debounce and abort.
- Do: keep one Zod schema module that both the RHF client form and the Server Action import, and validate again on the server. Store option ids, not labels.
- Do: in Next.js, fetch async options from a GET Route Handler (cacheable), not a Server Action.
- Don't: build a combobox from `div`s with click handlers, use `role="menu"` for values, or put buttons inside options.
- Don't: render API labels with `dangerouslySetInnerHTML` for match highlighting.
- Verify before done: keyboard-only walkthrough (Tab in, ArrowDown, type, Enter, Escape, Tab out), axe clean, 200% zoom, a mobile viewport, and a test asserting the selected id appears in the submitted payload.

## Examples

```tsx
// Base UI multi-select combobox with chips
'use client';
import {Combobox} from '@base-ui/react/combobox';

export function LabelsPicker({labels}: {labels: string[]}) {
  return (
    <Combobox.Root items={labels} multiple name="labels">
      <Combobox.Label>Labels</Combobox.Label>
      <Combobox.Chips>
        <Combobox.Value>
          {(selected: string[]) => selected.map((l) => (
            <Combobox.Chip key={l}>
              {l}<Combobox.ChipRemove aria-label={`Remove ${l}`}>×</Combobox.ChipRemove>
            </Combobox.Chip>
          ))}
        </Combobox.Value>
        <Combobox.Input placeholder="Add label" />
      </Combobox.Chips>
      <Combobox.Portal>
        <Combobox.Positioner>
          <Combobox.Popup>
            <Combobox.Empty>No labels found</Combobox.Empty>
            <Combobox.List>
              {(l: string) => <Combobox.Item key={l} value={l}><Combobox.ItemIndicator>✓</Combobox.ItemIndicator>{l}</Combobox.Item>}
            </Combobox.List>
          </Combobox.Popup>
        </Combobox.Positioner>
      </Combobox.Portal>
    </Combobox.Root>
  );
}
```
Part names follow the Base UI docs, but check exact exports (for example the chip remove part) against the installed version.

### One field, two form strategies (shared Zod v4 schema)

```tsx
// lib/schemas/shipping.ts — imported by BOTH the client form and the Server Action
import {z} from 'zod';

export const COUNTRY_CODES = ['GB', 'US', 'DE'] as const;
export const COUNTRY_LABELS: Record<(typeof COUNTRY_CODES)[number], string> = {GB: 'United Kingdom', US: 'United States', DE: 'Germany'};
export const COUNTRIES = COUNTRY_CODES.map((id) => ({id, name: COUNTRY_LABELS[id]}));

export const ShippingSchema = z.object({
  country: z.enum(COUNTRY_CODES, {error: 'Choose a country from the list'}),
});
export type Shipping = z.infer<typeof ShippingSchema>;
```

```tsx
// app/checkout/shipping/country-combobox.tsx — works controlled (RHF) or uncontrolled (Server Action)
'use client';
import {ComboBox, Label, Input, Button, Popover, ListBox, ListBoxItem, FieldError, type Key} from 'react-aria-components';
import {useState} from 'react';
import {COUNTRIES} from '@/lib/schemas/shipping';

type Props = {
  name?: string;                      // set for Server Actions → renders hidden input
  value?: string | null;              // set for controlled use (RHF)
  defaultValue?: string | null;
  onChange?: (value: string | null) => void;
  onBlur?: () => void;
  errorMessage?: string;
};

export function CountryCombobox({name, value, defaultValue = null, onChange, onBlur, errorMessage}: Props) {
  const [inner, setInner] = useState<string | null>(defaultValue);
  const selected = value !== undefined ? value : inner;
  return (
    <>
      {/* selectedKey/onSelectionChange: long-standing RAC API; newer docs also show value/onChange — follow your installed version */}
      <ComboBox
        defaultItems={COUNTRIES}
        selectedKey={selected}
        onSelectionChange={(key: Key | null) => {
          const next = key == null ? null : String(key);
          if (value === undefined) setInner(next);
          onChange?.(next);
        }}
        onBlur={onBlur}
        isInvalid={Boolean(errorMessage)}
        isRequired
      >
        <Label>Country</Label>
        <div className="field">
          <Input />
          <Button aria-label="Show countries">▾</Button>
        </div>
        <FieldError>{errorMessage}</FieldError>
        <Popover>
          <ListBox renderEmptyState={() => 'No countries match'}>
            {(c) => <ListBoxItem id={c.id}>{c.name}</ListBoxItem>}
          </ListBox>
        </Popover>
      </ComboBox>
      {name && <input type="hidden" name={name} value={selected ?? ''} />}
    </>
  );
}
```

```tsx
// A) Client-side: React Hook Form + zodResolver (app/checkout/shipping/shipping-form-client.tsx)
'use client';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {ShippingSchema, type Shipping} from '@/lib/schemas/shipping';
import {CountryCombobox} from './country-combobox';
import {saveShipping} from './actions';

export function ShippingFormClient() {
  const {control, handleSubmit, setError, formState: {isSubmitting}} = useForm<Shipping>({
    resolver: zodResolver(ShippingSchema),
    mode: 'onTouched', // validate after the user leaves the field, then live
  });

  const onSubmit = async (data: Shipping) => {
    const fd = new FormData();
    fd.set('country', data.country);
    const result = await saveShipping({ok: false}, fd); // server validates again
    if (!result.ok) setError('country', {message: result.errors?.country?.[0] ?? 'Could not save'});
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <Controller
        control={control}
        name="country"
        render={({field, fieldState}) => (
          <CountryCombobox
            value={field.value ?? null}
            onChange={(v) => field.onChange((v ?? undefined) as Shipping['country'] | undefined)}
            onBlur={field.onBlur}
            errorMessage={fieldState.error?.message}
          />
        )}
      />
      <button type="submit" disabled={isSubmitting}>{isSubmitting ? 'Saving…' : 'Continue'}</button>
    </form>
  );
}
```

```tsx
// B) Server Action + useActionState/useFormStatus
// app/checkout/shipping/actions.ts
'use server';
import {z} from 'zod';
import {ShippingSchema} from '@/lib/schemas/shipping';

export type ShippingState = {ok: boolean; errors?: {country?: string[]}; country?: string};

export async function saveShipping(_prev: ShippingState, formData: FormData): Promise<ShippingState> {
  const raw = formData.get('country');
  const parsed = ShippingSchema.safeParse({country: raw || undefined});
  if (!parsed.success) {
    return {ok: false, errors: z.flattenError(parsed.error).fieldErrors, country: typeof raw === 'string' ? raw : undefined};
  }
  // Check the session/authorization, then persist parsed.data
  return {ok: true, country: parsed.data.country};
}
```

```tsx
// app/checkout/shipping/shipping-form-action.tsx
'use client';
import {useActionState} from 'react';
import {useFormStatus} from 'react-dom';
import {saveShipping, type ShippingState} from './actions';
import {CountryCombobox} from './country-combobox';

function SubmitButton() {
  const {pending} = useFormStatus();
  return <button type="submit" disabled={pending}>{pending ? 'Saving…' : 'Continue'}</button>;
}

export function ShippingFormAction() {
  const [state, formAction] = useActionState<ShippingState, FormData>(saveShipping, {ok: false});
  return (
    <form action={formAction} noValidate>
      {/* key remounts the widget with the server-echoed value so React 19's post-action reset can't desync it */}
      <CountryCombobox key={state.country ?? 'empty'} name="country" defaultValue={state.country ?? null} errorMessage={state.errors?.country?.[0]} />
      <SubmitButton />
      <p role="status">{state.ok ? 'Shipping country saved' : ''}</p>
    </form>
  );
}
```

```tsx
// Async option loader with debounce + abort (usable from any client component)
export function createOptionLoader(url: string, delay = 200) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let ctrl: AbortController | undefined;
  return (query: string) => new Promise<{id: string; label: string}[]>((resolve, reject) => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      ctrl?.abort();
      ctrl = new AbortController();
      try {
        const res = await fetch(`${url}?q=${encodeURIComponent(query)}`, {signal: ctrl.signal});
        if (!res.ok) throw new Error(String(res.status));
        resolve(await res.json());
      } catch (e) {
        if ((e as Error).name !== 'AbortError') reject(e);
      }
    }, delay);
  });
}
```

```tsx
// Safe match highlighting (no innerHTML)
function Highlight({text, query}: {text: string; query: string}) {
  const i = text.toLowerCase().indexOf(query.toLowerCase());
  if (!query || i < 0) return <>{text}</>;
  return <>{text.slice(0, i)}<mark>{text.slice(i, i + query.length)}</mark>{text.slice(i + query.length)}</>;
}
```

## Related Skills
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — free-text input with optional suggestions
- [tags-and-chips-input](../tags-and-chips-input/Skill.md) — creating/removing many values as chips
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — better choice for short option sets
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — label, hint, error anatomy shared by all fields
- [form-validation-patterns](../form-validation-patterns/Skill.md) — required/invalid timing and messages
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — wiring controlled selects into forms
- [dropdown-menus](../dropdown-menus/Skill.md) — action menus (not value pickers)
- [command-palette](../command-palette/Skill.md) — global command search built on similar primitives
- [floating-element-positioning](../floating-element-positioning/Skill.md) — popup placement/flip
- [list-virtualization](../list-virtualization/Skill.md) — very long option lists
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — APG background
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — result count announcements
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md), [base-ui](../base-ui/Skill.md), [radix-ui-primitives](../radix-ui-primitives/Skill.md), [shadcn-ui](../shadcn-ui/Skill.md) — implementations
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — server-side re-validation and `useActionState` error flow
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — `useActionState`, `useFormStatus`, form reset behavior
- [progressive-enhancement](../progressive-enhancement/Skill.md) — native select before hydration

## Sources
- [WAI-ARIA APG: Combobox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/) — Official — roles/states, autocomplete types, keyboard table
- [WAI-ARIA APG: Listbox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/listbox/) — Official — multi-select keys, option content caution
- [MDN: Customizable select elements](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Customizable_select) — Official — `base-select`, `selectedcontent`, pseudo-elements, fallback
- [Chrome for Developers: customizable select](https://developer.chrome.com/blog/a-customizable-select) — Official — shipping status in Chromium
- [MDN: datalist](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/datalist) and [a11ysupport.io datalist](https://a11ysupport.io/tech/html/datalist_element) — Official / Community — datalist zoom and AT limitations
- [React Aria ComboBox](https://react-aria.adobe.com/ComboBox) — Open Source — `menuTrigger`, `allowsCustomValue`, `selectionMode`
- [Base UI Combobox](https://base-ui.com/react/components/combobox) — Open Source — anatomy, `multiple`, `Chips`, `virtualized`
- [Radix Select](https://www.radix-ui.com/primitives/docs/components/select) — Open Source — positioning modes, native form integration
- [Downshift](https://github.com/downshift-js/downshift) — Open Source — `useSelect`/`useCombobox`/`useTagGroup`, ARIA 1.2
- [alphagov/accessible-autocomplete](https://github.com/alphagov/accessible-autocomplete) — Open Source — progressive enhancement of select, live status
- [shadcn/ui changelog: CLI v4](https://ui.shadcn.com/docs/changelog/2026-03-cli-v4) — Open Source — Radix/Base UI choice

## License / Usage Notes
Guidance is summarized and paraphrased from W3C (W3C Document License), MDN (CC-BY-SA), and library docs. React Aria (Apache-2.0), Base UI, Radix, Downshift, shadcn/ui, and accessible-autocomplete are MIT-licensed. Code examples are original and illustrative. Verify exact exports against installed versions.

## Quality Tier
A — Grounded in APG, MDN, and current library docs with verified browser-support status. iOS VoiceOver behavior and some Base UI part names still need hands-on validation per version.

## Status
Active

## Last Verified
2026-09-15
