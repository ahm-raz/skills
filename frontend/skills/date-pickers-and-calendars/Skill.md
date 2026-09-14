# Date Pickers and Calendars

## Summary
How to collect dates, date ranges and date-times in React and Next.js (App Router, TypeScript): choosing between separate day/month/year text fields, segmented date fields, native `<input type="date">`, and calendar popovers; modeling date values without timezone bugs; building calendars that follow the WAI-ARIA APG date picker dialog / grid pattern; and validating the same Zod schema on the client (React Hook Form) and on the server (Server Actions). Covers React Aria Components, react-day-picker (now `@daypicker/react` v10), and the Temporal API (ES2026).

## Category
Components

## Subcategories
Date input, date range picker, calendar grid, time picker, internationalized dates, timezones, Temporal API, booking UIs, SSR hydration of dates

## Problem It Solves
Date entry is one of the most error-prone form interactions. Calendars are slow for dates people already know, like a birthday. Formats like `03/04/2026` are ambiguous and lead to wrong data. `new Date("2026-09-15")` silently shifts by a day in timezones behind UTC. Hand-rolled calendar widgets are often unusable with a keyboard or screen reader. In Next.js, a "today" computed on the server's clock can differ from the browser's and cause hydration mismatches. This skill helps you pick the right control and implement it correctly, end to end.

## When To Use
- Any form field asking for a day, a month/year, a date range, or a date plus time.
- Booking/scheduling UIs where users need to see availability in calendar context (hotels, appointments).
- Date range filters (reports, logs, analytics).
- Replacing a legacy or hand-rolled datepicker that fails accessibility audits.

## When Not To Use
- Memorable or document-sourced dates (date of birth, passport expiry): use three separate text fields (GOV.UK date input pattern), not a calendar.
- Relative/approximate periods ("last 7 days"): use a radio group or select of presets.
- Just a year or month+year (card expiry): one or two numeric text fields.
- Full scheduling/resource timelines: that is a calendar application, out of scope.

## Core Principles
1. Match the control to what the user knows. If they already know the date, let them type it. If they pick it based on weekdays or availability, show a calendar.
2. Typing must always be possible; a calendar is an enhancement, never the only input method.
3. Store and transmit plain dates as ISO `YYYY-MM-DD` strings (or `Temporal.PlainDate` / `CalendarDate`), never as a JS `Date` at local midnight.
4. One Zod schema module defines the rules; the client validates for fast feedback and the Server Action validates again as the authority.
5. Calendar grids follow the APG grid keyboard model with roving tabindex; the trigger announces the chosen date.
6. Validate in priority order: missing parts, then impossible dates, then business rules (range, past/future).

## Best Practices
- Label every field; put the format in visible hint text ("For example, 27 3 2007"), never only in a placeholder.
- Three-field date input: `inputMode="numeric"` on text inputs (not `type="number"`), widths for 2/2/4 characters, `autoComplete="bday-day" | "bday-month" | "bday-year"` for birthdays, grouped in `<fieldset>` + `<legend>`.
- Never auto-advance focus between day/month/year fields.
- Accept month names/abbreviations ("jan", "January") in the month field; GOV.UK research found this reduces errors.
- Show min/max constraints in hint text ("Within the next 60 days") instead of relying only on disabled calendar cells.
- Unavailable days need a non-color cue and, where possible, a reason.
- Today: `aria-current="date"` plus a visible ring; selected: `aria-selected="true"`.
- Ranges: style in-between days, announce both ends, allow typing each end separately.
- Respect locale first day of week and date format (React Aria uses the `I18nProvider` locale; react-day-picker takes a `locale`).
- Always label timezones for date-times not in the viewer's zone ("14:00 CET").
- On mobile, native `<input type="date">` gives the OS picker for free; fine for simple near-date choices.

## Implementation Guidance

### Decision table
| Question | Control |
|---|---|
| Date of birth, issue/expiry date | 3 text fields (day, month, year) |
| Near-future appointment, delivery day | React Aria `DatePicker` (segments + calendar) or native date input |
| Stay / report period | `DateRangePicker` or two typed fields + 2-month react-day-picker calendar |
| Month and year only | 2 numeric fields or month select + year field |
| Date + time | Separate date and time fields (`DateField`/`TimeField`), not a 1,440-option select |
| "Last 7/30/90 days" | Preset radio group + "Custom" range |

### Value modeling
```tsx
// lib/dates.ts
// BAD: parsed as UTC midnight, displays as the previous day in America/*
// new Date("2026-09-15").getDate() === 14 in New York

// GOOD: Temporal (ES2026; Chrome/Edge 144+, Firefox 139+, Safari behind flag -> polyfill)
export const addDaysIso = (iso: string, days: number): string =>
  Temporal.PlainDate.from(iso).add({ days }).toString();

// GOOD: React Aria ecosystem
import { parseDate, today, getLocalTimeZone, type CalendarDate } from "@internationalized/date";
export const tomorrow = (): CalendarDate => today(getLocalTimeZone()).add({ days: 1 });
export const fromIso = (iso: string): CalendarDate => parseDate(iso);
```
- Date-only: `PlainDate` / `CalendarDate`, serialized `YYYY-MM-DD`, stored in a SQL `DATE` column.
- Instant (meeting start): UTC ISO instant plus the IANA zone the user chose (`ZonedDateTime`).
- Temporal (Sept 2026): Stage 4, shipped in Chrome/Edge 144 and Firefox 139; Safari still behind a flag. Load `temporal-polyfill` only when `typeof Temporal === "undefined"`.

### Keyboard (calendar grid, APG date picker dialog)
| Key | Action |
|---|---|
| Arrow Left / Right | Previous / next day |
| Arrow Up / Down | Same weekday previous / next week |
| Home / End | First / last day of the week |
| Page Up / Page Down | Same day previous / next month |
| Shift + Page Up / Page Down | Same day previous / next year |
| Enter / Space | Select focused day (single mode closes and returns focus to trigger) |
| Escape | Close without change; focus returns to trigger |
| Tab | Cycles month nav buttons, the grid (one tabbable cell), dialog actions |

### ARIA structure
- Trigger: `<button aria-label="Choose date">`; after selection its name becomes "Change date, 15 September 2026".
- Popover: `role="dialog"` labelled by the month heading; focus moves to the selected (or today's) cell on open.
- Month/year heading: `aria-live="polite"` so month changes are announced.
- Grid: `<table role="grid">`, weekday headers with full names in `abbr`, roving `tabIndex` (exactly one `0`), `aria-selected`, `aria-disabled` on unavailable days, full date as each cell's accessible name.
- Segmented fields (React Aria `DateInput`) expose each segment as `role="spinbutton"` with `aria-valuetext`.

### Validation and submission architecture
| Layer | Responsibility |
|---|---|
| `lib/schemas/*.ts` (shared, no `"use server"`/`"use client"`) | Zod schema: required parts, real-date check, range rules |
| Client form (RHF + `zodResolver`) | Instant feedback, focus first error, then call the Server Action |
| Server Action (`"use server"`) | Auth, `safeParse` again with the same schema, persist ISO date, return field errors |
| `useActionState` form | Progressive enhancement: works before hydration; server errors rendered from state |

Business rules relative to "today" are evaluated server-side in a defined zone (user's stored zone or the service zone); the client check is advisory.

## Recommended Workflow
1. Classify the question (memorable / near-term choice / range / date-time) with the decision table.
2. Decide the data model (PlainDate vs ZonedDateTime) and write the shared Zod schema first.
3. Pick implementation: three text fields, native input, React Aria `DatePicker`/`DateRangePicker`, or react-day-picker in your own popover.
4. Build the form both ways as needed: RHF + Zod for rich client behavior, or `<form action>` + `useActionState` for progressive enhancement. Both call the same server validation.
5. Map each error to the specific segment (day/month/year) and to an error summary.
6. Handle SSR: mark picker components `"use client"`; compute "today" on the client or pass the user's zone from the server.
7. Test keyboard grid navigation, announcements, DST and timezone offsets (run tests with `TZ=America/Los_Angeles` and `TZ=Pacific/Kiritimati`).

## Patterns

### Shared schema module (memorable date)
```tsx
// lib/schemas/dob.ts
import { z } from "zod";

const MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
export const normalizeMonth = (m: string): string => {
  const i = MONTHS.indexOf(m.trim().slice(0, 3).toLowerCase());
  return i >= 0 ? String(i + 1) : m.trim();
};

export const dobSchema = z
  .object({
    day: z.string().trim().min(1, "Date of birth must include a day"),
    month: z.string().trim().min(1, "Date of birth must include a month"),
    year: z.string().trim().min(1, "Date of birth must include a year"),
  })
  // Runs only after all parts are present -> matches GOV.UK error priority
  .superRefine((v, ctx) => {
    const d = Number(v.day), m = Number(normalizeMonth(v.month)), y = Number(v.year);
    const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
    if (![d, m, y].every(Number.isInteger) || y < 1900 || m < 1 || m > 12 || d < 1 || d > daysInMonth) {
      ctx.addIssue({ code: "custom", path: ["day"], message: "Date of birth must be a real date" });
      return;
    }
    if (toIsoDate(v) > new Date().toISOString().slice(0, 10)) {
      ctx.addIssue({ code: "custom", path: ["year"], message: "Date of birth must be in the past" });
    }
  });

export type DobInput = z.infer<typeof dobSchema>;

export const toIsoDate = (v: DobInput): string =>
  `${v.year.padStart(4, "0")}-${normalizeMonth(v.month).padStart(2, "0")}-${v.day.padStart(2, "0")}`;
```

### Server Actions (re-validate on the server)
```tsx
// app/profile/dob/actions.ts
"use server";
import { z } from "zod";
import { dobSchema, toIsoDate, type DobInput } from "@/lib/schemas/dob";
import { requireUser } from "@/lib/auth";
import { saveDateOfBirth } from "@/lib/data/profile";

export type DobState = {
  ok: boolean;
  errors?: Partial<Record<keyof DobInput, string[]>>;
  values?: DobInput;
};

export async function saveDob(input: unknown): Promise<DobState> {
  const user = await requireUser(); // Server Actions are public endpoints: always authorize
  const parsed = dobSchema.safeParse(input);
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  await saveDateOfBirth(user.id, toIsoDate(parsed.data)); // store "YYYY-MM-DD" in a DATE column
  return { ok: true };
}

export async function saveDobAction(_prev: DobState, formData: FormData): Promise<DobState> {
  const values = {
    day: String(formData.get("day") ?? ""),
    month: String(formData.get("month") ?? ""),
    year: String(formData.get("year") ?? ""),
  };
  const result = await saveDob(values);
  return result.ok ? result : { ...result, values };
}
```

### Shared presentational fields
```tsx
// app/profile/dob/dob-fields.tsx
import type { InputHTMLAttributes } from "react";

type PartProps = { id: string; label: string; width: string } & InputHTMLAttributes<HTMLInputElement>;

function Part({ id, label, width, ...rest }: PartProps) {
  return (
    <div className="flex flex-col">
      <label htmlFor={id}>{label}</label>
      <input id={id} type="text" inputMode="numeric" spellCheck={false} className={width} {...rest} />
    </div>
  );
}

export function DobFields({ error, invalid, field }: {
  error?: string;
  invalid: Partial<Record<"day" | "month" | "year", boolean>>;
  field: (name: "day" | "month" | "year") => InputHTMLAttributes<HTMLInputElement>;
}) {
  return (
    <fieldset aria-describedby={error ? "dob-hint dob-error" : "dob-hint"}>
      <legend>What is your date of birth?</legend>
      <p id="dob-hint">For example, 27 3 2007</p>
      {error && <p id="dob-error" className="text-red-700"><span className="sr-only">Error: </span>{error}</p>}
      <div className="flex gap-4">
        <Part id="dob-day" label="Day" width="w-[5ch]" autoComplete="bday-day" aria-invalid={invalid.day} {...field("day")} />
        <Part id="dob-month" label="Month" width="w-[5ch]" autoComplete="bday-month" aria-invalid={invalid.month} {...field("month")} />
        <Part id="dob-year" label="Year" width="w-[7ch]" autoComplete="bday-year" aria-invalid={invalid.year} {...field("year")} />
      </div>
    </fieldset>
  );
}
```

### Way 1: client-side React Hook Form + Zod
```tsx
// app/profile/dob/dob-form-client.tsx
"use client";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { dobSchema, type DobInput } from "@/lib/schemas/dob";
import { saveDob } from "./actions";
import { DobFields } from "./dob-fields";

export function DobFormClient() {
  const { register, handleSubmit, setError, formState: { errors, isSubmitting, isSubmitSuccessful } } =
    useForm<DobInput>({ resolver: zodResolver(dobSchema), mode: "onSubmit", reValidateMode: "onBlur",
      defaultValues: { day: "", month: "", year: "" } });

  const onSubmit = async (values: DobInput) => {
    const res = await saveDob(values); // server validates again with the same schema
    if (!res.ok) {
      for (const [name, msgs] of Object.entries(res.errors ?? {})) {
        setError(name as keyof DobInput, { message: msgs?.[0] });
      }
    }
  };

  const error = errors.day?.message ?? errors.month?.message ?? errors.year?.message;
  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <DobFields error={error} field={(n) => register(n)}
        invalid={{ day: !!errors.day, month: !!errors.month, year: !!errors.year }} />
      <button type="submit" disabled={isSubmitting}>{isSubmitting ? "Saving…" : "Continue"}</button>
      <p role="status">{isSubmitSuccessful && !error ? "Date of birth saved" : ""}</p>
    </form>
  );
}
```

### Way 2: Server Action + useActionState / useFormStatus
```tsx
// app/profile/dob/dob-form-action.tsx
"use client";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { saveDobAction, type DobState } from "./actions";
import { DobFields } from "./dob-fields";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" aria-disabled={pending}>{pending ? "Saving…" : "Continue"}</button>;
}

export function DobFormAction() {
  const [state, formAction] = useActionState<DobState, FormData>(saveDobAction, { ok: false });
  const e = state.errors;
  // React 19 resets uncontrolled fields after an action; defaultValue restores what the user typed on error
  return (
    <form action={formAction} noValidate>
      <DobFields error={e?.day?.[0] ?? e?.month?.[0] ?? e?.year?.[0]}
        invalid={{ day: !!e?.day, month: !!e?.month, year: !!e?.year }}
        field={(n) => ({ name: n, defaultValue: state.values?.[n] ?? "" })} />
      <SubmitButton />
      <p role="status">{state.ok ? "Date of birth saved" : ""}</p>
    </form>
  );
}
```

### Picker inside a Server Action form
React Aria `DatePicker` with a `name` prop submits its value as an ISO string in `FormData`, so the shared schema can be `z.object({ deliveryDate: z.iso.date() })` plus a range refinement, and the same Server Action pattern applies.

### Server-authoritative availability
Fetch unavailable days per visible month (Route Handler or cached server function), prefetch adjacent months, feed `isDateUnavailable` / `disabled`, and re-check availability in the Server Action on submit.

## Anti-Patterns
- **Calendar-only input for date of birth**: users have to page back 40 years. Fix: three text fields.
- **`new Date(isoDateString)` for date-only values**: off-by-one errors in timezones behind UTC. Fix: `PlainDate`/`CalendarDate`, or split the string into parts.
- **Validating only in the client resolver**: Server Actions can be invoked directly. Fix: `safeParse` with the shared schema in the action.
- **Duplicated schemas in client and server files**: they drift apart. Fix: one `lib/schemas` module imported by both.
- **Computing "today" during SSR and rendering it**: hydration mismatch near midnight and across zones. Fix: compute on the client (effect or client-only component) or pass the user's zone.
- **Placeholder `dd/mm/yyyy` as the only format hint**: it disappears on input. Fix: persistent hint text.
- **Auto-tabbing between segments**: breaks correction and Shift+Tab. Fix: let users Tab themselves.
- **`type="number"` for date parts**: adds spinners, the scroll wheel changes values, and leading zeros are lost. Fix: `inputMode="numeric"` text inputs.
- **Unavailable dates only greyed out**: fails WCAG 1.4.1. Fix: `aria-disabled`, a pattern or strikethrough, and explanation text.
- **Every day cell is a tab stop**: that means 42 Tab presses. Fix: roving tabindex.
- **Sending `date.toISOString()` for a local date**: the backend stores the previous day at 22:00Z. Fix: send `YYYY-MM-DD` built from local getters.

## Accessibility
- WCAG 1.3.1 (fieldset/legend, table semantics), 1.3.5 (bday autocomplete tokens), 3.3.1/3.3.3 (specific errors), 2.1.1 (full keyboard), 2.4.3 (focus order on open/close), 4.1.2 (name/role/value of cells and segments), 4.1.3 (status messages for save/selection), 1.4.1 (no color-only states), 2.5.8 (cells at least 24x24 CSS px; aim for 44).
- Month navigation announced via `aria-live="polite"` heading; cells named with full dates.
- After a failed submit, move focus to an error summary or the first invalid part (RHF `shouldFocusError` does this for registered inputs).
- Screen reader users must be able to type the date without touching the grid.

## Responsive Design
- Below ~480px: one month, full-screen sheet or native date input instead of a small popover.
- Day cells at least 44px on touch; a 7-column grid needs about 320px.
- Range pickers: `numberOfMonths` 1 on narrow containers, 2 on wide (use container queries or a `matchMedia` hook in a client component).
- Swipe to change month is optional; next/previous buttons are required.

## Performance
- Prefer `@internationalized/date` (calendar-system aware) or Temporal plus polyfill; tree-shaken date-fns for formatting. Avoid Moment.js.
- Render the text field immediately; lazy-load heavy calendar popovers with `next/dynamic` or `React.lazy` when opened.
- Memoize disabled-day matchers and `Intl.DateTimeFormat` instances; don't create formatters per cell.

## Security
- Enforce min/max, availability and business rules in the Server Action/Route Handler; client constraints are advisory.
- Strict server parsing rejects `2026-02-30` and non-ISO strings (`z.iso.date()` plus a real-date check).
- Authorize every Server Action; don't leak other users' bookings via availability APIs (return booleans only).

## Testing
- Unit (Vitest): shared schema cases for missing parts, impossible dates, leap years, future dates; run under multiple `TZ` values.
- Component (Testing Library): type parts, submit, assert error text and `aria-invalid`; open calendar, Arrow/Page keys, Escape restores focus.
- Server Action tests: call `saveDob` with malformed payloads directly, which proves server validation works without the client.
- E2E (Playwright): `locale: "de-DE"`, `timezoneId: "America/Los_Angeles"`; test with JavaScript disabled for the `useActionState` form.
- Accessibility: axe plus manual NVDA/VoiceOver on the grid.

## Tooling
- **React Aria Components** (`DatePicker`, `DateRangePicker`, `Calendar`, `RangeCalendar`, `DateField`, `TimeField`) + `@internationalized/date`. Active; strongest a11y/i18n; `name` enables native form submission.
- **react-day-picker**: v10 (May 2026) prefers `@daypicker/react` and removed v9-deprecated props (`fromDate`, `toDate`, `fromYear`, `toYear`, `initialFocus`, touch/pointer day handlers). Use `startMonth`/`endMonth`, `disabled` matchers, `mode="single" | "multiple" | "range"`. Calendar only; you supply input and popover. The shadcn/ui Calendar wraps it, so check the pinned major.
- **Native `<input type="date">`**: Baseline; good on mobile, limited styling, no ranges.
- **Temporal** (ES2026) + `temporal-polyfill`. **date-fns v4** for formatting. Moment.js is legacy.
- **React Hook Form** + `@hookform/resolvers` (Zod v4 support) and **Zod v4** (`z.iso.date()`, `z.flattenError`).
- MUI X Date Pickers, Mantine Dates: full-featured alternatives inside those ecosystems.

## Framework Notes
- **React (Vite SPA)**: no SSR concerns; call a typed API (fetch or tRPC) from the RHF submit handler, and re-validate on the backend with the same schema package (share via a workspace package). Wrap the app in React Aria `I18nProvider` when the locale differs from the browser's.
- **Next.js App Router**:
  - Picker, calendar and RHF form components are client components (`"use client"`); keep the page a Server Component that passes initial ISO strings as props.
  - Avoid rendering "today", relative dates or locale-formatted dates from server time in markup the client re-renders. Pass the user's timezone/locale from the server (cookie or profile), or render the formatted value in a client-only child. `suppressHydrationWarning` is a last resort for a single text node.
  - Heavy calendar popovers can be `next/dynamic(() => import("./calendar-popover"), { ssr: false })`, but only from a client component. `ssr: false` is not allowed in Server Components.
  - Server Actions live in `"use server"` files; the shared schema module must not import server-only code so the client bundle can use it.
  - `useActionState` (from `react`) and `useFormStatus` (from `react-dom`) give progressive enhancement: the form submits before hydration.
  - Revalidate affected data after saving (`revalidatePath` / `revalidateTag`) inside the action.

## AI Agent Guidance
- Do: infer what the date represents before choosing a control; default DOB-like questions to three text inputs.
- Do: keep values as `YYYY-MM-DD` in form state, `FormData` and database; flag any `new Date("YYYY-MM-DD")` or `toISOString()` on local dates.
- Do: create one shared Zod schema in `lib/schemas`, use it in `zodResolver` and in the Server Action's `safeParse`, and authorize inside the action.
- Do: check `package.json` for the react-day-picker major (v9 vs v10 `@daypicker/react`) and Zod major (v4 APIs `z.iso.date`, `z.flattenError`).
- Don't: hand-roll a calendar grid, use `type="number"` parts, auto-advance focus, or rely on disabled cells as validation.
- Don't: import a `"use server"` module's internals into client code except the exported actions.
- Verify before done: keyboard grid table works; focus returns to trigger; errors identify the exact part; server rejects invalid payloads when called directly; no hydration warnings; tests pass in two timezones; form works with JS disabled (action variant).

## Examples

### React Aria DatePicker (client component, submits ISO via name)
```tsx
"use client";
import {
  DatePicker, Label, Group, DateInput, DateSegment, Button, Popover, Dialog,
  Calendar, Heading, CalendarGrid, CalendarCell, FieldError, Text,
} from "react-aria-components";
import { today, getLocalTimeZone, isWeekend } from "@internationalized/date";
import { useLocale } from "react-aria-components";

export function DeliveryDate({ error }: { error?: string }) {
  const { locale } = useLocale();
  const now = today(getLocalTimeZone()); // client-only component: no server/client clock mismatch
  return (
    <DatePicker name="deliveryDate" isRequired minValue={now.add({ days: 1 })} maxValue={now.add({ days: 60 })}
      isDateUnavailable={(d) => isWeekend(d, locale)} isInvalid={!!error} validationBehavior="aria">
      <Label>Delivery date</Label>
      <Text slot="description">Within the next 60 days, weekdays only</Text>
      <Group className="flex items-center gap-2">
        <DateInput className="flex">{(segment) => <DateSegment segment={segment} />}</DateInput>
        <Button aria-label="Open calendar">▼</Button>
      </Group>
      <FieldError>{error}</FieldError>
      <Popover>
        <Dialog>
          <Calendar>
            <header className="flex justify-between">
              <Button slot="previous" aria-label="Previous month">‹</Button>
              <Heading />
              <Button slot="next" aria-label="Next month">›</Button>
            </header>
            <CalendarGrid>{(date) => <CalendarCell date={date} className="size-11" />}</CalendarGrid>
          </Calendar>
        </Dialog>
      </Popover>
    </DatePicker>
  );
}
```
Mount it inside a page with `dynamic(() => import("./delivery-date").then((m) => m.DeliveryDate), { ssr: false })` from a client wrapper if "today" must never render on the server.

### react-day-picker v10 range with ISO conversion
```tsx
"use client";
import { useState } from "react";
import { DayPicker, type DateRange } from "@daypicker/react";

const toIso = (d: Date): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

export function StayPicker() {
  const [range, setRange] = useState<DateRange | undefined>();
  return (
    <fieldset>
      <legend>Dates of stay</legend>
      <DayPicker mode="range" min={1} numberOfMonths={2} selected={range} onSelect={setRange}
        disabled={{ before: new Date() }} startMonth={new Date()}
        footer={<p aria-live="polite">{range?.from && range?.to
          ? `${range.from.toDateString()} to ${range.to.toDateString()}` : "Choose check-in and check-out"}</p>} />
      <input type="hidden" name="checkIn" value={range?.from ? toIso(range.from) : ""} />
      <input type="hidden" name="checkOut" value={range?.to ? toIso(range.to) : ""} />
    </fieldset>
  );
}
```
Import the library stylesheet in the root layout or a CSS entry; verify the v10 CSS subpath in the installed package. Add typed "Check-in"/"Check-out" fields alongside the calendar for keyboard-first users.

## Related Skills
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — resolver setup and shared schemas
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security, revalidation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState / useFormStatus
- [form-validation-patterns](../form-validation-patterns/Skill.md) — error priority and timing
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — labels, hints, input modes for date parts
- [form-design-ux](../form-design-ux/Skill.md) — question design
- [popovers](../popovers/Skill.md) — calendar popover container
- [accessible-dialogs](../accessible-dialogs/Skill.md) — modal date picker focus management
- [keyboard-navigation](../keyboard-navigation/Skill.md) — roving tabindex grids
- [frontend-i18n-architecture](../frontend-i18n-architecture/Skill.md) — locale formats and calendars
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — date range filters
- [progressive-enhancement](../progressive-enhancement/Skill.md) — forms that work before hydration
- [react-aria-and-spectrum](../react-aria-and-spectrum/Skill.md) — library reference

## Sources
- [WAI-ARIA APG Date Picker Dialog example](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/examples/datepicker-dialog/) — Official — keyboard table, roving tabindex, live heading, trigger label
- [GOV.UK Design System: Date input](https://design-system.service.gov.uk/components/date-input/) — Official — when to use, error priority, bday tokens, no auto-tab, month names
- [React Aria DatePicker](https://react-aria.adobe.com/DatePicker) — Open Source — anatomy, props, @internationalized/date
- [React DayPicker changelog](https://daypicker.dev/changelog) — Open Source — v10 breaking changes and `@daypicker/react` rename
- [React DayPicker accessibility guide](https://daypicker.dev/guides/accessibility) — Open Source — labels, live region footer
- [InfoQ: Chrome 144 ships Temporal](https://www.infoq.com/news/2026/02/chrome-temporal-date-api/) — Community — Temporal ship status
- [Web Platform Features: Temporal](https://web-platform-dx.github.io/web-features-explorer/features/temporal/) — Official — cross-browser status
- [MDN input type=date](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/date) — Official — native control behavior

## License / Usage Notes
React Aria (Apache-2.0), react-day-picker (MIT), React Hook Form (MIT), Zod (MIT), Temporal polyfills (MIT/BSD), GOV.UK Design System (MIT code, OGL content), W3C APG (W3C document license). Content is summarized and paraphrased; code examples are original and should be checked against installed versions.

## Quality Tier
A — grounded in APG, GOV.UK research and current library docs verified Sept 2026. The Safari Temporal timeline, the react-day-picker v10 CSS subpath and exact Zod v4 helper names should be rechecked on upgrade.

## Status
Active

## Last Verified
2026-09-15
