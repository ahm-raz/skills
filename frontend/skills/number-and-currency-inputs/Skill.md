# Number and Currency Inputs

## Summary
How to collect numeric values in React/Next.js (quantities, prices, percentages, measurements) with locale-aware parsing and formatting, correct mobile keyboards, safe precision, and an accessible stepper where incrementing makes sense. Explains why native `type="number"` is usually the wrong tool, what the APG spinbutton pattern requires, how React Aria and Base UI NumberField handle formatting and parsing, and how to validate amounts with one shared Zod schema in both React Hook Form and Server Actions.

## Category
Components

## Subcategories
number field, spinbutton, stepper, currency input, percent input, unit input, Intl.NumberFormat, locale parsing, decimal precision, minor units, quantity selector

## Problem It Solves
Numbers fail in subtle ways: `1.234,56` vs `1,234.56` across locales, the scroll wheel changing a price, leading zeros stripped, floating-point errors (`0.1 + 0.2`), currencies with different minor units (JPY has 0, KWD has 3), masks that fight the caret, steppers that keyboard and screen reader users can't operate, and `z.coerce.number()` silently turning an empty field into `0` on the server.

## When To Use
- Quantities with meaningful increments (cart quantity, number of guests).
- Money amounts, percentages, measurements with units.
- Design-system `NumberField` / `CurrencyField` components.

## When Not To Use
- Identifiers made of digits (card, account, phone numbers, postcodes, OTPs): use a text input with `inputMode="numeric"`. See [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) and [otp-and-auth-forms](../otp-and-auth-forms/Skill.md).
- Approximate values on a continuum: [sliders-and-range-inputs](../sliders-and-range-inputs/Skill.md).
- Dates and times: [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md).

## Core Principles
1. Ask whether incrementing makes sense. If not, it isn't a spinbutton; it's a text field that happens to hold digits.
2. Store and send numbers in a canonical form (a number, integer minor units, or a decimal string). Display them in the user's locale.
3. Parse leniently and format on blur. Never reformat under the caret while the user types.
4. Money is never a binary float in business logic. Use integer minor units or a decimal library. The server is the source of truth.
5. Make the currency or unit visible and part of the accessible name, not just a decorative symbol.
6. State min/max/step up front and enforce them with clear messages, not silent clamping.
7. One Zod schema defines the range and precision; the client and server both run it.

## Best Practices
- Default for amounts: a NumberField (React Aria / Base UI) or `<input type="text" inputMode="decimal">` plus your own parser. GOV.UK advises against `type="number"`.
- Format with `Intl.NumberFormat(locale, { style: 'currency', currency })`. Get separators for parsing from `formatToParts`.
- Read fraction digits from the currency: `new Intl.NumberFormat('en', { style: 'currency', currency: 'JPY' }).resolvedOptions().maximumFractionDigits` → 0.
- Put the currency in the label when it could be ambiguous ("Amount, in US dollars"). `$` alone could mean USD, CAD, or AUD.
- Turn off wheel changes: React Aria `isWheelDisabled`. Base UI only scrubs with the wheel if you set `allowWheelScrub`.
- Stepper buttons need names ("Increase quantity") and at least 24px targets (44px on touch). React Aria keeps them out of the tab order because the input handles arrow keys.
- Commit on blur/Enter. React Aria `commitBehavior="validate"` keeps an out-of-range value and marks it invalid; `"snap"` clamps it. For money, prefer validate plus a message so users never submit a silently clamped value.
- Accept pasted values that include currency symbols, spaces, and group separators ("$1,200.50").
- Percent: decide whether you store 0.15 or 15 and document it. React Aria `style: 'percent'` stores 0.15.
- Server side, never use `z.coerce.number()` directly on `FormData`: `Number('')` is `0`. Convert empty to `NaN` or `undefined` first so "required" errors still fire.

## Implementation Guidance

### Decision table
| Need | Control |
|---|---|
| Integer quantity, increments are common | NumberField with steppers (spinbutton) |
| Price / amount entry | NumberField with `formatOptions` currency and no steppers, or text + `inputMode="decimal"` + parser |
| Digit identifier | Text input `inputMode="numeric"`, kept as a string |
| Approximate value in a range | Slider (optionally linked to a number field) |
| Very small set of values | Radios or a segmented control |

### Why not `type="number"`
- The wheel and arrow keys can change the value by accident.
- It accepts `e`, `+`, `-` anywhere. For partial input, `valueAsNumber` is `NaN` and `value` may be `''`, which hides what the user actually typed.
- Browsers handle locale decimals differently, leading zeros are stripped, and spinners are tiny.
- It's acceptable for simple internal integer fields where none of this matters.

### Spinbutton ARIA (APG)
- `role="spinbutton"` on the focusable input, plus `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-valuetext` for formatted values ("€1,200.00"), a name, and `aria-invalid` when out of range.
- Focus stays in the text field, and normal text-editing keys keep working. React Aria and Base UI implement this.

### Keyboard
| Key | Action |
|---|---|
| Up / Down Arrow | Increase / decrease by `step` |
| Page Up / Page Down | Larger step (optional) |
| Home / End | Set to min / max (if defined) |
| Shift + Arrow / Alt + Arrow | Base UI `largeStep` / `smallStep` |
| Typing, Backspace, Delete | Normal text editing |
| Enter, Tab, blur | Commit: parse, validate or clamp, format |

### Locale-aware parse (when not using a NumberField)
React Aria's `NumberParser` (`@internationalized/number`) also handles non-Latin numbering systems (e.g., Arabic-Indic digits), so prefer it for international products. The snippet below is a minimal version for Latin digits only.

### Money handling
- Convert to minor units right away and reject extra decimals for the currency.
- Send `{ amountMinor: 120050, currency: 'USD' }` or a decimal string, never a float that gets summed.
- The server recomputes totals. The client only displays them.

## Recommended Workflow
1. Classify each numeric field with the decision table.
2. Define the canonical storage, range, step, and precision in a shared Zod schema.
3. Choose the component: React Aria NumberField (strongest locale parsing) or Base UI NumberField (headless parts, scrub area).
4. Configure `locale` and `Intl.NumberFormat` options, and label the currency or unit.
5. Wire it to React Hook Form with `Controller`, or to a Server Action through the field's `name` (the hidden input submits the raw number).
6. In the Server Action, convert `FormData` to a number safely, `safeParse`, then convert to minor units.
7. Test in `en-US`, `de-DE`, `fr-FR`, `ja-JP`, `ar-EG`, plus paste, keyboard, and screen reader.

## Patterns
- **Quantity stepper**: `[−] [ 2 ] [+]`. The input stays editable, and the buttons are disabled at the bounds (the library does this).
- **Currency amount**: `formatOptions={{ style: 'currency', currency }}`, a label that names the currency, `commitBehavior="validate"`, and wheel disabled.
- **Currency selector + amount**: grouped with `role="group"` and a name. Changing currency re-validates the fraction digits (schema `superRefine`).
- **Unit field**: `formatOptions={{ style: 'unit', unit: 'kilogram', unitDisplay: 'short' }}`.
- **Linked slider + number field**: both bound to the same state; the number field is where precise values go.
- **Scrub area** (Base UI `NumberField.ScrubArea`): drag to adjust in design tools, with a typeable input always available.

## Anti-Patterns
- **`type="number"` for prices or card numbers**: wheel changes, `e` accepted, leading zeros lost. Fix: NumberField, or text + `inputMode` + parser.
- **Reformatting on every keystroke**: the caret jumps. Fix: format on blur (NumberField does this).
- **`parseFloat('1.234,56')`** gives 1.234 in German input. Fix: a locale-aware parser.
- **`z.coerce.number()` on raw `FormData`**: an empty field becomes 0 and passes `min(0)`. Fix: map `''` to `NaN` first.
- **Float math on money**. Fix: minor units, or `dinero.js` / `big.js`.
- **Hard-coded `.toFixed(2)`**: wrong for JPY and KWD. Fix: `resolvedOptions().maximumFractionDigits`.
- **Silent clamping**: the user types 15000 and gets 10000. Fix: `commitBehavior="validate"` with an error.
- **Currency only in an `aria-hidden` prefix**. Fix: put it in the label or the formatted value.
- **Trusting client totals**. Fix: recompute on the server.

## Accessibility
- Name comes from `<Label>`. The description states the range ("Between €1 and €10,000").
- Spinbutton role and properties per APG, with `aria-valuetext` for formatted values.
- Errors: text + `aria-invalid` + `aria-describedby` (SC 3.3.1, 3.3.3). With React Aria, pass `isInvalid` and render `<FieldError>`.
- Don't show negative numbers by color alone; include the minus sign or "(debit)" (SC 1.4.1).
- Stepper targets meet SC 2.5.8.
- Screen readers read formatted amounts differently; check "€1.200,50" in VoiceOver and NVDA.

## Responsive Design
- `inputMode="decimal"` shows a decimal key on iOS/Android. iOS decimal pads have no minus key, so offer a +/- toggle if negatives are allowed on mobile.
- Enlarge stepper buttons on coarse pointers, and stack the currency selector above the amount on narrow screens.
- Pick one alignment for amounts in forms and keep it consistent across the product.

## Performance
- Cache `Intl.NumberFormat` instances per locale and options (module-level `Map`). Don't create them per render in table cells.
- NumberField `onChange` fires on commit, not on every keystroke, so controlled form state doesn't re-render on each character.

## Security
- The server re-validates range, precision, and currency, and recomputes totals and prices from its own data, never from the client.
- Reject exponent notation and very long strings before decimal parsing.
- Use idempotent payment submission. See [buttons-and-actions](../buttons-and-actions/Skill.md).
- Server Actions are public endpoints: authenticate and `safeParse` in every action.

## Testing
- Parser and minor-unit helpers: table-driven Vitest cases across locales (`'1.234,56'@de-DE → 1234.56`, `'1 234,56'@fr-FR` with narrow NBSP, `'¥1,200'@ja-JP`, `''` → invalid).
- Schema tests: NaN, below min, above max, too many decimals for the currency.
- Component tests: ArrowUp increases by step, Home/End go to the bounds, blur formats, out of range shows the error; assert `aria-valuenow` / `aria-valuetext`.
- Server Action test: `FormData` with `amount=''` returns "Enter an amount", not success.
- Playwright: use the `locale` context option to run in several locales; a wheel event over the field doesn't change the value.
- Property-based tests (fast-check) for minor-unit round-trips.

## Tooling
- React Aria `NumberField` + `@internationalized/number` (`NumberFormatter`, `NumberParser`). Active; best locale support.
- Base UI `NumberField` (Root, Group, Input, Increment, Decrement, ScrubArea; `format`, `locale`, `step`/`smallStep`/`largeStep`, `onValueCommitted`). Active.
- Mantine `NumberInput`, `react-number-format`. Active alternatives; check caret behavior in your locales.
- `Intl.NumberFormat`: native, Baseline.
- `dinero.js` v2, `big.js`, `decimal.js` for money and decimal arithmetic.
- Zod 4 + `@hookform/resolvers`. Active.

## Framework Notes
- **React (Vite SPA)**: bind NumberField to React Hook Form with `Controller`. NumberField gives `number` (or `NaN` when empty), which fits a `z.number()` schema directly. Submit JSON to your API with the number (or minor units); the API imports the same schema and runs `safeParse` again. Get the locale from the browser (`navigator.language`) or your i18n library, and wrap the app in `I18nProvider`.
- **Next.js (App Router)**: React Aria NumberField renders a hidden input with `name` that submits the raw number, so Server Action forms work without extra wiring. Map `''` → `NaN` before `safeParse`. Use `defaultValue={state.values?.amount}` to survive React 19 form reset. Get the locale on the server (route segment, cookie, `Accept-Language`) and pass it to `I18nProvider` so server and client render the same formatted text (no hydration mismatch). NumberField components need `'use client'`.

## AI Agent Guidance
- Do: classify numeric fields first; use NumberField or text + `inputMode` for amounts; format with `Intl`; store money as minor units; put range and precision in one shared Zod schema; map empty `FormData` values to `NaN`; test with `de-DE`.
- Don't: emit `type="number"` for money, phones, cards, or codes; hard-code `.toFixed(2)`; reformat while typing; `z.coerce.number()` raw form data; trust client totals.
- Verify before done: pasting "€1.200,50" in de-DE parses correctly; the wheel doesn't change the value; arrows work on steppers; the screen reader announces the formatted value; an empty submit shows the required error in both RHF and Server Action paths; the server rejects out-of-range or over-precise values posted directly.

## Examples
```tsx
// lib/money.ts — currency-aware helpers shared by client and server
const fmtCache = new Map<string, Intl.NumberFormat>();

export function currencyFormatter(locale: string, currency: string) {
  const key = `${locale}|${currency}`;
  let f = fmtCache.get(key);
  if (!f) fmtCache.set(key, (f = new Intl.NumberFormat(locale, { style: 'currency', currency })));
  return f;
}

export function fractionDigits(currency: string) {
  return new Intl.NumberFormat('en', { style: 'currency', currency }).resolvedOptions().maximumFractionDigits ?? 2;
}

export function toMinorUnits(value: number, currency: string) {
  const scaled = value * 10 ** fractionDigits(currency);
  if (Math.abs(scaled - Math.round(scaled)) > 1e-6) throw new Error(`Too many decimals for ${currency}`);
  return Math.round(scaled);
}

// Minimal Latin-digit parser for plain text inputs (prefer @internationalized/number NumberParser)
export function parseLocaleNumber(input: string, locale: string): number {
  const parts = new Intl.NumberFormat(locale).formatToParts(12345.6);
  const group = parts.find((p) => p.type === 'group')?.value ?? ',';
  const decimal = parts.find((p) => p.type === 'decimal')?.value ?? '.';
  const cleaned = input
    .replace(/[\s  ]/g, '')
    .replace(/−/g, '-')
    .replace(/[^\d\-.,'’]/g, '')
    .split(group).join('')
    .replace(decimal, '.');
  return /^-?\d+(\.\d+)?$/.test(cleaned) ? Number(cleaned) : Number.NaN;
}
```

```tsx
// app/donate/schema.ts — ONE schema for RHF and the Server Action
import { z } from 'zod';
import { fractionDigits } from '@/lib/money';

export const CURRENCIES = ['EUR', 'USD', 'JPY'] as const;

export const donationSchema = z
  .object({
    currency: z.enum(CURRENCIES, 'Select a currency'),
    amount: z
      .number('Enter an amount')                       // rejects NaN (empty field)
      .min(1, 'Enter an amount of 1 or more')
      .max(10_000, 'Enter an amount of 10,000 or less'),
  })
  .superRefine(({ amount, currency }, ctx) => {
    const digits = fractionDigits(currency);
    const scaled = amount * 10 ** digits;
    if (Math.abs(scaled - Math.round(scaled)) > 1e-6) {
      ctx.addIssue({
        code: 'custom',
        path: ['amount'],
        message: digits === 0 ? 'Enter a whole amount, without decimals' : `Enter an amount with up to ${digits} decimal places`,
      });
    }
  });

export type DonationInput = z.infer<typeof donationSchema>;
export type DonationState = {
  ok: boolean;
  message?: string;
  errors?: Partial<Record<keyof DonationInput, string[]>>;
  values?: { amount?: number; currency?: string };
};
```

```tsx
// app/donate/actions.ts — the server always re-validates
'use server';
import { z } from 'zod';
import { donationSchema, type DonationState } from './schema';
import { toMinorUnits } from '@/lib/money';
import { createDonation } from '@/lib/server/payments';

async function handle(input: unknown): Promise<DonationState> {
  const parsed = donationSchema.safeParse(input);
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  const { amount, currency } = parsed.data;
  await createDonation({ amountMinor: toMinorUnits(amount, currency), currency }); // never a float to the PSP
  return { ok: true, message: 'Thank you for your donation' };
}

export async function donateAction(_prev: DonationState, formData: FormData): Promise<DonationState> {
  const raw = formData.get('amount');
  const amount = raw === null || raw === '' ? Number.NaN : Number(raw); // NOT z.coerce: '' would become 0
  const currency = String(formData.get('currency') ?? '');
  const result = await handle({ amount, currency });
  return result.ok ? result : { ...result, values: { amount: Number.isNaN(amount) ? undefined : amount, currency } };
}

export async function donate(input: unknown): Promise<DonationState> {
  return handle(input);
}
```

```tsx
// app/donate/donate-form-action.tsx — Server Action + useActionState + useFormStatus
'use client';
import { useActionState, useState } from 'react';
import { NumberField, Label, Input, FieldError, Text, I18nProvider } from 'react-aria-components';
import { donateAction } from './actions';
import { CURRENCIES, type DonationState } from './schema';
import { SubmitButton } from '@/components/ui/submit-button';

export function DonateFormAction({ locale }: { locale: string }) {
  const [state, formAction] = useActionState<DonationState, FormData>(donateAction, { ok: false });
  const [currency, setCurrency] = useState<string>(state.values?.currency ?? 'EUR');
  const amountError = state.errors?.amount?.[0];

  return (
    <I18nProvider locale={locale}>
      <form action={formAction} noValidate className="grid max-w-sm gap-6">
        <div className="grid gap-1">
          <label htmlFor="currency">Currency</label>
          <select id="currency" name="currency" value={currency} onChange={(e) => setCurrency(e.target.value)}
            className="min-h-11 text-base">
            {CURRENCIES.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>

        <NumberField
          name="amount"                               // hidden input submits the raw number
          defaultValue={state.values?.amount}
          minValue={1}
          maxValue={10_000}
          formatOptions={{ style: 'currency', currency }}
          commitBehavior="validate"
          isWheelDisabled
          isInvalid={!!amountError}
          validationBehavior="aria"
          className="grid gap-1"
        >
          <Label>Donation amount, in {currency}</Label>
          <Text slot="description">Between 1 and 10,000</Text>
          <Input inputMode="decimal" className="min-h-11 rounded border-2 px-3 text-base" />
          <FieldError className="text-red-700">{amountError}</FieldError>
        </NumberField>

        <SubmitButton pendingLabel="Processing…">Donate</SubmitButton>
        <p role="status">{state.ok ? state.message : ''}</p>
      </form>
    </I18nProvider>
  );
}
```

```tsx
// app/donate/donate-form-rhf.tsx — React Hook Form + Zod with Controller, same schema
'use client';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { NumberField, Label, Input, FieldError, Text, I18nProvider } from 'react-aria-components';
import { donationSchema, CURRENCIES, type DonationInput } from './schema';
import { donate } from './actions';
import { Button } from '@/components/ui/button';

export function DonateFormRHF({ locale }: { locale: string }) {
  const [status, setStatus] = useState('');
  const { control, register, watch, handleSubmit, setError, formState: { isSubmitting } } = useForm<DonationInput>({
    resolver: zodResolver(donationSchema),
    mode: 'onTouched',
    defaultValues: { currency: 'EUR', amount: Number.NaN },
  });
  const currency = watch('currency');

  const onSubmit = handleSubmit(async (values) => {
    const res = await donate(values);                 // server re-validates
    if (!res.ok) {
      const msg = res.errors?.amount?.[0];
      if (msg) setError('amount', { message: msg }, { shouldFocus: true });
      return;
    }
    setStatus(res.message ?? 'Done');
  });

  return (
    <I18nProvider locale={locale}>
      <form onSubmit={onSubmit} noValidate className="grid max-w-sm gap-6">
        <div className="grid gap-1">
          <label htmlFor="rhf-currency">Currency</label>
          <select id="rhf-currency" {...register('currency')} className="min-h-11 text-base">
            {CURRENCIES.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>

        <Controller
          control={control}
          name="amount"
          render={({ field: { ref, value, onChange, onBlur, name }, fieldState }) => (
            <NumberField
              name={name}
              value={value}
              onChange={onChange}
              onBlur={onBlur}
              minValue={1}
              maxValue={10_000}
              formatOptions={{ style: 'currency', currency }}
              commitBehavior="validate"
              isWheelDisabled
              isInvalid={fieldState.invalid}
              validationBehavior="aria"
              className="grid gap-1"
            >
              <Label>Donation amount, in {currency}</Label>
              <Text slot="description">Between 1 and 10,000</Text>
              <Input ref={ref} inputMode="decimal" className="min-h-11 rounded border-2 px-3 text-base" />
              <FieldError className="text-red-700">{fieldState.error?.message}</FieldError>
            </NumberField>
          )}
        />

        <Button type="submit" pending={isSubmitting}>{isSubmitting ? 'Processing…' : 'Donate'}</Button>
        <p role="status">{status}</p>
      </form>
    </I18nProvider>
  );
}
```

```tsx
// components/quantity-field.tsx — Base UI stepper for integer quantities
'use client';
import { NumberField } from '@base-ui/react/number-field';

export function QuantityField({ name = 'quantity', defaultValue = 1 }: { name?: string; defaultValue?: number }) {
  return (
    <NumberField.Root name={name} defaultValue={defaultValue} min={1} max={20} step={1} className="grid gap-1">
      <label htmlFor="qty">Quantity</label>
      <NumberField.Group className="flex">
        <NumberField.Decrement aria-label="Decrease quantity" className="size-11 border">−</NumberField.Decrement>
        <NumberField.Input id="qty" className="w-16 border-y text-center text-base" />
        <NumberField.Increment aria-label="Increase quantity" className="size-11 border">+</NumberField.Increment>
      </NumberField.Group>
    </NumberField.Root>
  );
}
```

## Related Skills
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — base field anatomy and inputMode
- [sliders-and-range-inputs](../sliders-and-range-inputs/Skill.md) — approximate numeric input
- [form-validation-patterns](../form-validation-patterns/Skill.md) — range errors and timing
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — Controller and schema typing
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — secure mutations
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState and form reset
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — where the locale comes from
- [checkout-flow-design](../checkout-flow-design/Skill.md) — amounts and totals
- [fintech-ui-patterns](../fintech-ui-patterns/Skill.md) — money display conventions

## Sources
- [WAI-ARIA APG: Spinbutton Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/spinbutton/) — Official — keyboard and ARIA properties
- [GOV.UK Design System: Text input](https://design-system.service.gov.uk/components/text-input/) — Official — avoid type=number, use inputmode
- [MDN: Intl.NumberFormat formatToParts](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat/formatToParts) — Official — part types for parsing
- [MDN: input type=number](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/number) — Official — native caveats
- [React Aria NumberField](https://react-aria.adobe.com/NumberField) — Open Source — formatOptions, commitBehavior, isWheelDisabled, commit-time onChange, name
- [Base UI NumberField](https://base-ui.com/react/components/number-field) — Open Source — parts, step modifiers, onValueCommitted, allowWheelScrub
- [Zod 4 docs](https://zod.dev/api) — Open Source — number schemas, superRefine, flattenError
- [Next.js docs: Forms](https://nextjs.org/docs/app/guides/forms) — Official — Server Action validation pattern

## License / Usage Notes
Summarized from W3C, MDN (CC-BY-SA), GOV.UK (MIT/OGL), React Aria (Apache-2.0), Base UI (MIT), Zod (MIT), Next.js docs. Parser, schema, and form code are original and meant as illustrations.

## Quality Tier
A — standards plus two leading library implementations checked, with complete dual-stack validation; the custom parser handles Latin digits only, which is stated in the code.

## Status
Active

## Last Verified
2026-09-15
