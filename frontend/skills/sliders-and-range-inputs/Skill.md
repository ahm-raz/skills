# Sliders and Range Inputs

## Summary
How to implement single-value and multi-thumb (range) sliders in React and Next.js (TypeScript) that work with keyboard, screen readers and touch. Covers when a slider beats a number field, native `<input type="range">`, the WAI-ARIA APG slider and multi-thumb patterns, `aria-valuetext`, live vs commit events, and paired numeric inputs for precision. Form examples use one shared Zod schema, submitted through React Hook Form or Server Actions and re-validated on the server. Libraries covered: Base UI, Radix and React Aria.

## Category
Components

## Subcategories
Range input, multi-thumb slider, price range filter, volume/brightness controls, stepped sliders, vertical sliders, value formatting, URL-synced filters

## Problem It Solves
Sliders are fast for approximate adjustments with immediate feedback. They are poor for precise values, hard to use with tremors or on small touch screens, and custom `div` sliders often lack keyboard support, value announcements, or form participation. Range sliders add problems of their own: thumbs colliding, dynamic min/max, and tab order. Filter sliders in React apps also tend to fire a request on every pointer move.

## When To Use
- Approximate values with immediate visual feedback: volume, brightness, zoom, opacity, image adjustments.
- Range filters where rough bounds are fine (price, distance), ideally paired with number inputs.
- Small discrete scales with labelled ticks where visual position helps.

## When Not To Use
- Precise values (exact amount, age, quantity): number field (see number-and-currency-inputs).
- Huge ranges with fine granularity: inputs, or logarithmic scale plus inputs.
- A few non-numeric options: radio group or segmented control.
- Star ratings: radio group pattern.

## Core Principles
1. Prefer native `<input type="range">` for single values; use an APG-compliant library for ranges.
2. Every thumb is focusable, labelled, exposes `role="slider"` with `aria-valuenow/min/max` and human `aria-valuetext`.
3. Always show the current value as text.
4. Dragging must not be the only way to set a value (WCAG 2.5.7): keyboard, track click, and/or paired inputs.
5. Separate live updates (visual) from committed changes (network, URL, expensive work).
6. The server re-validates submitted values with the same schema; min < max and bounds are enforced there.

## Best Practices
- Visible label; for ranges, distinct thumb labels ("Minimum price", "Maximum price").
- Format with `Intl.NumberFormat` in both visible output and `aria-valuetext`; create formatters once (module scope or `useMemo`).
- Min/max labels at track ends; ticks for small step counts (`<datalist>` on native).
- Thumb hit area at least 44×44px on touch; at least 24×24 for WCAG 2.5.8.
- `largeStep` (Page Up/Down) around 10% of range.
- Visible focus ring on the thumb with 3:1 contrast (1.4.11).
- Filled track between min and value (or between thumbs).
- Commit events (or debounce) for fetching and URL updates; keep visual output live.
- Pair range sliders with two synced number inputs; validate min < max on blur and on the server.
- RTL: libraries flip direction automatically based on `dir`; test it.

## Implementation Guidance

### Decision table
| Need | Implementation |
|---|---|
| Single value, standard look | Native range input + `accent-color` (Tailwind `accent-*`) |
| Range (two thumbs) | Base UI / Radix / React Aria slider |
| Precise value also needed | Slider + synced number input |
| Non-linear scale | Library slider mapping position to value; `aria-valuetext` shows real value |
| Vertical | Library `orientation="vertical"` |
| Filter that updates results | Commit event → URL search params (nuqs) or Server Component refetch |

### Keyboard (APG slider)
| Key | Action |
|---|---|
| Arrow Right / Arrow Up | Increase one step |
| Arrow Left / Arrow Down | Decrease one step |
| Page Up / Page Down | Increase / decrease by large step |
| Home | Minimum |
| End | Maximum |
| Tab | Next thumb in fixed DOM order regardless of visual position |

### ARIA (custom sliders)
| Attribute | Where | Notes |
|---|---|---|
| `role="slider"` | Each thumb | Native range input already has it |
| `aria-valuenow` | Thumb | Current value |
| `aria-valuemin` / `aria-valuemax` | Thumb | Dynamic for ranges: min thumb's max = max thumb's value |
| `aria-valuetext` | Thumb | "$250", "75 percent", "Large" |
| `aria-label` / `aria-labelledby` | Thumb | Distinct per thumb |
| `aria-orientation="vertical"` | Thumb | Only when vertical |

### Events by library
| Library | Live | Commit |
|---|---|---|
| Native | `onInput` / React `onChange` (fires live in React) | native `change` via `ref.addEventListener("change")`, or `onPointerUp`/`onKeyUp` |
| Base UI | `onValueChange` | `onValueCommitted` |
| Radix | `onValueChange` | `onValueCommit` |
| React Aria | `onChange` | `onChangeEnd` |

React's `onChange` on range inputs fires continuously (like `input`), not only on release.

### Validation and submission architecture
| Layer | Responsibility |
|---|---|
| `lib/schemas/price-alert.ts` (shared) | `min`/`max` coerced numbers, bounds, step, `min < max` refinement |
| Client (RHF `Controller` or hidden inputs) | Numbers in state; instant feedback |
| Server Action | Auth, `safeParse` same schema, persist |

## Recommended Workflow
1. Confirm a slider is right; otherwise use number input or radios.
2. Define min, max, step, large step, formatting, mapping; put bounds in the shared schema module as constants.
3. Choose native (single) or library (range/heavy styling).
4. Add visible output, min/max labels, paired inputs for precision.
5. Wire live vs commit events to rendering vs fetching/URL/actions.
6. Build the form both ways if needed; server re-validates.
7. Style focus, touch targets, disabled, `forced-colors`.
8. Test keyboard table, screen readers (including iOS VoiceOver swipe), touch, RTL, direct action calls.

## Patterns

### Native single slider with output (TSX)
```tsx
"use client";
import { useId, useState } from "react";

export function VolumeSlider({ defaultValue = 40, onCommit }: { defaultValue?: number; onCommit?: (v: number) => void }) {
  const id = useId();
  const [value, setValue] = useState(defaultValue);
  return (
    <div className="flex items-center gap-3">
      <label htmlFor={id}>Volume</label>
      <input id={id} name="volume" type="range" min={0} max={100} step={1} value={value}
        aria-valuetext={`${value} percent`}
        onChange={(e) => setValue(e.currentTarget.valueAsNumber)} // live
        onPointerUp={() => onCommit?.(value)} onKeyUp={() => onCommit?.(value)} // commit
        className="h-11 w-full accent-blue-600 focus-visible:outline-2 focus-visible:outline-offset-4" />
      <output htmlFor={id} className="tabular-nums">{value}%</output>
    </div>
  );
}
```
For fully custom native styling, set `appearance: none` and restyle `::-webkit-slider-runnable-track`, `::-webkit-slider-thumb`, `::-moz-range-track`, `::-moz-range-progress` and `::-moz-range-thumb` in a CSS module. You must also restyle focus.

### Stepped slider with labelled ticks
Native range `step={1} min={1} max={5}` + `list` pointing to a `<datalist>`; render tick labels positioned with CSS; set `aria-valuetext` to the label ("Large").

### Logarithmic mapping
Internal position 0–1000 → `value = min * (max / min) ** (pos / 1000)`; snap to nice numbers; show and announce the mapped value.

### Filter slider synced to the URL (Next.js)
Keep live state local; on commit write `?min=&max=` with nuqs (`useQueryStates` with `shallow: false` to refetch Server Components) or `router.replace`; parse and validate search params on the server with the same schema.

### Shared schema module
```tsx
// lib/schemas/price-alert.ts
import { z } from "zod";

export const PRICE_MIN = 0;
export const PRICE_MAX = 1000;
export const PRICE_STEP = 10;

export const priceAlertSchema = z
  .object({
    min: z.coerce.number().int().min(PRICE_MIN).max(PRICE_MAX).multipleOf(PRICE_STEP, "Use steps of $10"),
    max: z.coerce.number().int().min(PRICE_MIN).max(PRICE_MAX).multipleOf(PRICE_STEP, "Use steps of $10"),
  })
  .refine((v) => v.min < v.max, { path: ["max"], message: "Maximum price must be higher than minimum price" });

export type PriceAlertInput = z.input<typeof priceAlertSchema>;
export type PriceAlert = z.output<typeof priceAlertSchema>;
```

### Server Actions
```tsx
// app/alerts/actions.ts
"use server";
import { z } from "zod";
import { priceAlertSchema, type PriceAlert } from "@/lib/schemas/price-alert";
import { requireUser } from "@/lib/auth";
import { savePriceAlert } from "@/lib/data/alerts";

export type AlertState = { ok: boolean; errors?: Partial<Record<keyof PriceAlert, string[]>>; values?: PriceAlert };

export async function saveAlert(input: unknown): Promise<AlertState> {
  const user = await requireUser();
  const parsed = priceAlertSchema.safeParse(input); // same schema as the client
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  await savePriceAlert(user.id, parsed.data);
  return { ok: true, values: parsed.data };
}

export async function saveAlertAction(_prev: AlertState, formData: FormData): Promise<AlertState> {
  return saveAlert({ min: formData.get("min"), max: formData.get("max") });
}
```

### Reusable range slider (Base UI)
```tsx
// components/price-range.tsx
"use client";
import { Slider } from "@base-ui/react/slider";
import { PRICE_MAX, PRICE_MIN, PRICE_STEP } from "@/lib/schemas/price-alert";

const fmt = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });
const thumb = "relative size-5 rounded-full bg-blue-600 before:absolute before:-inset-3 before:content-[''] " +
  "has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 forced-colors:bg-[CanvasText]";

export function PriceRange({ value, onChange, onCommit, error }: {
  value: [number, number];
  onChange: (v: [number, number]) => void;
  onCommit?: (v: [number, number]) => void;
  error?: string;
}) {
  const clamp = (n: number) => Math.min(PRICE_MAX, Math.max(PRICE_MIN, Number.isFinite(n) ? n : PRICE_MIN));
  return (
    <fieldset aria-describedby={error ? "price-error" : undefined}>
      <legend>Price range</legend>
      <Slider.Root value={value} min={PRICE_MIN} max={PRICE_MAX} step={PRICE_STEP} largeStep={100}
        minStepsBetweenValues={1}
        onValueChange={(v) => onChange(v as [number, number])}
        onValueCommitted={(v) => onCommit?.(v as [number, number])}>
        <Slider.Control className="flex h-11 items-center">
          <Slider.Track className="relative h-1 w-full rounded bg-gray-300">
            <Slider.Indicator className="rounded bg-blue-600 forced-colors:bg-[Highlight]" />
            <Slider.Thumb index={0} className={thumb} getAriaLabel={() => "Minimum price"}
              getAriaValueText={(_formatted, v) => fmt.format(v)} />
            <Slider.Thumb index={1} className={thumb} getAriaLabel={() => "Maximum price"}
              getAriaValueText={(_formatted, v) => fmt.format(v)} />
          </Slider.Track>
        </Slider.Control>
      </Slider.Root>
      <div className="flex gap-4">
        <label>Minimum ($)
          <input type="text" inputMode="numeric" value={value[0]}
            onChange={(e) => onChange([clamp(Number(e.target.value)), value[1]])} onBlur={() => onCommit?.(value)} />
        </label>
        <label>Maximum ($)
          <input type="text" inputMode="numeric" value={value[1]}
            onChange={(e) => onChange([value[0], clamp(Number(e.target.value))])} onBlur={() => onCommit?.(value)} />
        </label>
      </div>
      {error && <p id="price-error" className="text-red-700">{error}</p>}
    </fieldset>
  );
}
```
Verify the `getAriaValueText` callback signature and `@base-ui/react` import path against the installed version.

### Way 1: React Hook Form + Zod
```tsx
// app/alerts/alert-form-client.tsx
"use client";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { priceAlertSchema, type PriceAlert, type PriceAlertInput } from "@/lib/schemas/price-alert";
import { PriceRange } from "@/components/price-range";
import { saveAlert } from "./actions";

export function AlertFormClient() {
  const { control, handleSubmit, setError, formState: { errors, isSubmitting } } =
    useForm<PriceAlertInput, unknown, PriceAlert>({
      resolver: zodResolver(priceAlertSchema), defaultValues: { min: 50, max: 400 },
    });

  const onSubmit = async (values: PriceAlert) => {
    const res = await saveAlert(values); // server validates again
    for (const [k, msgs] of Object.entries(res.errors ?? {})) setError(k as keyof PriceAlert, { message: msgs?.[0] });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <Controller control={control} name="min" render={({ field: minField }) => (
        <Controller control={control} name="max" render={({ field: maxField }) => (
          <PriceRange value={[Number(minField.value), Number(maxField.value)]}
            onChange={([a, b]) => { minField.onChange(a); maxField.onChange(b); }}
            error={errors.min?.message ?? errors.max?.message} />
        )} />
      )} />
      <button type="submit" disabled={isSubmitting}>{isSubmitting ? "Saving…" : "Create alert"}</button>
    </form>
  );
}
```

### Way 2: Server Action + useActionState / useFormStatus
```tsx
// app/alerts/alert-form-action.tsx
"use client";
import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { PriceRange } from "@/components/price-range";
import { saveAlertAction, type AlertState } from "./actions";

function SaveButton() {
  const { pending } = useFormStatus();
  return <button type="submit" aria-disabled={pending}>{pending ? "Saving…" : "Create alert"}</button>;
}

export function AlertFormAction() {
  const [state, formAction] = useActionState<AlertState, FormData>(saveAlertAction, { ok: false });
  const [range, setRange] = useState<[number, number]>([50, 400]); // React state survives the post-action form reset
  return (
    <form action={formAction} noValidate>
      <PriceRange value={range} onChange={setRange} error={state.errors?.min?.[0] ?? state.errors?.max?.[0]} />
      <input type="hidden" name="min" value={range[0]} />
      <input type="hidden" name="max" value={range[1]} />
      <SaveButton />
      <p role="status">{state.ok ? `Alert saved for ${state.values?.min}–${state.values?.max} dollars` : ""}</p>
    </form>
  );
}
```
Explicit hidden inputs make `FormData` independent of each library's internal input naming.

## Anti-Patterns
- **Slider for exact numeric entry**: frustrating, and fails users with motor impairments. Fix: a number input, optionally alongside the slider.
- **`div` thumb with pointer handlers only**: no keyboard or AT support. Fix: native input or an APG-compliant library.
- **No visible value / missing `aria-valuetext`**: users guess, and screen readers say "250" instead of "$250". Fix: `<output>` plus valuetext.
- **Thumbs cross and swap DOM order**: tab order and labels break. Fix: `minStepsBetweenValues` / `minStepsBetweenThumbs`.
- **Fetching or `router.push` on every `onValueChange`**: request storms and history spam. Fix: commit event plus `router.replace`/nuqs.
- **Trusting slider bounds client-side**: FormData can carry any value. Fix: shared schema `safeParse` in the Server Action.
- **Using React `onChange` assuming it fires on release**: it fires live. Fix: use commit callbacks.
- **Tiny thumbs**: fails WCAG 2.5.8. Fix: a hit area of at least 44px via a pseudo-element.
- **Removing focus styles with `appearance: none`**: focus becomes invisible. Fix: explicit focus-visible styles.
- **Color-only filled track**: fails 1.4.1. Fix: numeric output.

## Accessibility
- WCAG 2.1.1 keyboard (full APG keys), 4.1.2 name/role/value, 2.5.7 dragging alternative (track click, inputs), 2.5.8 target size, 1.4.11 non-text contrast, 1.3.1 labels/fieldset, 4.1.3 announce filter result counts politely.
- `forced-colors: active`: track/thumb stay visible via system colors (`CanvasText`, `Highlight`).
- Mobile screen readers adjust sliders via swipe up/down; test VoiceOver iOS and TalkBack.
- Respect `prefers-reduced-motion` for thumb/indicator transitions.

## Responsive Design
- Full-width track on mobile; value label above the thumb, not under the finger.
- Libraries set `touch-action: none` on the control only; don't block page scroll elsewhere.
- Mobile filter sheets: slider + inputs, apply on "Show results".
- Avoid vertical sliders on phones.

## Performance
- Keep slider state local to the slider component; don't lift live values into large context trees.
- Throttle expensive previews with `requestAnimationFrame`; use `useDeferredValue` for heavy result lists derived from live values.
- Commit to URL/server with `startTransition` so input stays responsive.
- Native range has zero JS cost; Base UI/Radix sliders are small.

## Security
- Re-validate and clamp in Server Actions / Route Handlers / search-param parsing.
- Don't derive public slider bounds from private data (e.g., internal cost floors).

## Testing
- Unit (Vitest): shared schema (bounds, step, min < max, coercion from strings).
- Component (Testing Library): `getByRole("slider", { name: "Minimum price" })`, `userEvent.keyboard("{ArrowRight}{PageUp}{End}")`, assert `aria-valuenow`/`aria-valuetext`; thumbs can't cross.
- Action tests: call `saveAlert({ min: "900", max: "100" })` and `{ min: "-5" }` directly.
- Playwright: `locator.fill("60")` on native range; keyboard or `mouse` drags for custom; mobile emulation; URL updates only on commit.
- axe plus a manual screen reader swipe test.

## Tooling
- **Native `<input type="range">`**: Baseline; single thumb; `accent-color`.
- **Base UI Slider** (`@base-ui/react`): Active. Parts: `Root`, `Label`, `Value`, `Control`, `Track`, `Indicator`, `Thumb`. Each Thumb renders a nested `<input type="range">`. Root props: `value`/`defaultValue`, `onValueChange`, `onValueCommitted`, `step`, `largeStep`, `minStepsBetweenValues`, `thumbAlignment`, `format`, `locale`, `orientation`. Thumb props: `getAriaLabel`, `getAriaValueText`, `index` (needed for SSR range sliders). Used by shadcn/ui's Base variant.
- **Radix Slider** (`radix-ui`): Active; `Root`, `Track`, `Range`, `Thumb`; `onValueCommit`, `minStepsBetweenThumbs`, `inverted`.
- **React Aria Slider** (`react-aria-components`): Active; `Slider`, `Label`, `SliderOutput`, `SliderTrack`, `SliderThumb`; `onChangeEnd`, `formatOptions`, strong RTL/i18n.
- **nuqs**: type-safe URL state for filter sliders. **React Hook Form** + `@hookform/resolvers`, **Zod v4**.
- MUI Slider, Mantine `Slider`/`RangeSlider`: Active alternatives within those ecosystems.

## Framework Notes
- **React (Vite SPA)**: sliders are plain client components. Sync filter sliders to the URL with nuqs (React SPA adapter) or your router's search params on commit. Submit forms via RHF to your API, which re-validates with the shared schema package.
- **Next.js App Router**:
  - Slider components need `"use client"`; pages remain Server Components that read `searchParams`, validate with the schema, and fetch.
  - Range sliders render thumbs during SSR, so give Base UI Thumbs an explicit `index` to avoid hydration mismatches. Initial values come from server props, not `window`.
  - Filters: on commit, update search params (nuqs `shallow: false` or `router.replace`) inside `startTransition`; show pending UI via `useTransition`.
  - Forms: `useActionState` + `useFormStatus` with hidden inputs, or RHF calling the Server Action; the action always re-validates.
  - With shadcn/ui, check whether the project uses the Radix or Base UI slider variant, because prop names differ (`onValueCommit` vs `onValueCommitted`).

## AI Agent Guidance
- Do: question whether a slider is right; add number inputs when precision matters.
- Do: native range for single values; library for ranges; never hand-roll pointer math without the full APG keyboard set.
- Do: distinct thumb labels, `aria-valuetext`, visible output, commit events for network/URL work.
- Do: shared Zod schema with exported bounds used by the slider props, `zodResolver`, and Server Action `safeParse`.
- Don't: remove focus styles, shrink hit areas below 24px, or push router history on every value change.
- Verify before done: Arrow/Page/Home/End work per thumb; thumbs don't cross; valuetext announced; touch drag on a real phone; server rejects out-of-range and min ≥ max payloads; no hydration warnings; RTL flips correctly.

## Examples

### React Aria single slider with commit to URL (Next.js)
```tsx
"use client";
import { Slider, Label, SliderOutput, SliderTrack, SliderThumb } from "react-aria-components";
import { useRouter, useSearchParams, usePathname } from "next/navigation";
import { useState, useTransition } from "react";

export function DistanceFilter({ initial }: { initial: number }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [value, setValue] = useState(initial);
  const [isPending, startTransition] = useTransition();

  return (
    <Slider value={value} onChange={setValue} minValue={1} maxValue={100} step={1}
      formatOptions={{ style: "unit", unit: "kilometer" }}
      onChangeEnd={(v) => startTransition(() => {
        const next = new URLSearchParams(params);
        next.set("distance", String(v));
        router.replace(`${pathname}?${next}`, { scroll: false });
      })}>
      <div className="flex justify-between"><Label>Distance</Label><SliderOutput /></div>
      <SliderTrack className="relative h-11 w-full">
        <SliderThumb className="top-1/2 size-6 rounded-full bg-blue-600 data-[focus-visible]:outline-2" />
      </SliderTrack>
      <span role="status" className="sr-only">{isPending ? "Updating results" : ""}</span>
    </Slider>
  );
}
```
The page's Server Component parses `searchParams.distance` with a Zod schema (`z.coerce.number().int().min(1).max(100).catch(25)`) before querying.

## Related Skills
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) — precise alternative and paired inputs
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — price/distance range facets
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — committing filter values to the URL
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — Controller integration and shared schemas
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — server re-validation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState, useTransition
- [checkbox-radio-switch](../checkbox-radio-switch/Skill.md) — discrete choice alternatives
- [aria-authoring-practices](../aria-authoring-practices/Skill.md) — APG slider patterns
- [touch-and-pointer-accessibility](../touch-and-pointer-accessibility/Skill.md) — target size, dragging alternatives
- [base-ui](../base-ui/Skill.md) — Base UI Slider
- [radix-ui-primitives](../radix-ui-primitives/Skill.md) — Radix Slider
- [css-logical-properties-and-rtl](../css-logical-properties-and-rtl/Skill.md) — RTL direction

## Sources
- [WAI-ARIA APG Slider (Multi-Thumb) pattern](https://www.w3.org/WAI/ARIA/apg/patterns/slider-multithumb/) — Official — fixed tab order, dynamic min/max, valuetext
- [WAI-ARIA APG Slider pattern](https://www.w3.org/WAI/ARIA/apg/patterns/slider/) — Official — keyboard table and roles
- [Base UI Slider](https://base-ui.com/react/components/slider) — Open Source — anatomy, props, nested range input
- [Radix UI Slider](https://www.radix-ui.com/primitives/docs/components/slider) — Open Source — parts and commit event
- [React Aria Slider](https://react-aria.adobe.com/Slider) — Open Source — anatomy, onChangeEnd, formatOptions
- [MDN input type=range](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/range) — Official — native behavior, datalist ticks
- [WCAG 2.2 Understanding 2.5.7 Dragging Movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html) — Official — single-pointer alternative

## License / Usage Notes
Base UI (MIT), Radix (MIT), React Aria (Apache-2.0), nuqs (MIT), React Hook Form (MIT), Zod (MIT), W3C APG/WCAG (W3C document license). Summarized in original words; code is original and should be checked against installed versions.

## Quality Tier
A — built on APG and WCAG 2.2 plus verified Base UI anatomy. Radix and React Aria prop names come from established docs that were not re-fetched this cycle.

## Status
Active

## Last Verified
2026-09-15
