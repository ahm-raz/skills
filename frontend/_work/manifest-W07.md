# Manifest — W07 Components: Inputs & Forms

Scope: React + Next.js (TypeScript) only, per TAXONOMY.md scope note (2026-09-15). All 17 assigned slugs written; 0 skipped; 0 extra slugs added (`address-and-phone-inputs` and `color-pickers` were considered and declined — see Gaps).

Validation performed: all 17 files contain the 27 template headings in order; all 86 distinct cross-linked slugs exist in TAXONOMY.md; no Vue/Nuxt/Angular/Svelte/Solid/Astro/Qwik references; Last Verified = 2026-09-15.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| form-design-ux | Form Design UX | Components | React / Next.js | A | Active | https://design-system.service.gov.uk/patterns/validation/ |
| form-validation-patterns | Form Validation Patterns | Components | React / Next.js | A | Active | https://design-system.service.gov.uk/patterns/validation/ |
| react-hook-form-and-zod | React Hook Form and Zod | Components | React / Next.js | A | Active | https://github.com/react-hook-form/resolvers |
| multi-step-forms-and-wizards | Multi-Step Forms and Wizards | Components | React / Next.js | A | Active | https://design-system.service.gov.uk/patterns/question-pages/ |
| buttons-and-actions | Buttons and Actions | Components | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/button/ |
| text-inputs-and-fields | Text Inputs and Fields | Components | React / Next.js | A | Active | https://design-system.service.gov.uk/components/text-input/ |
| number-and-currency-inputs | Number and Currency Inputs | Components | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/spinbutton/ |
| otp-and-auth-forms | OTP and Auth Forms | Components | React / Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API |
| checkbox-radio-switch | Checkbox, Radio, and Switch | Components | React / Next.js | S | Active | https://www.w3.org/WAI/ARIA/apg/patterns/switch/ |
| select-and-combobox | Select and Combobox | Components | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/combobox/ |
| search-and-autocomplete | Search and Autocomplete | Components | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/combobox/ |
| tags-and-chips-input | Tags and Chips Input | Components | React / Next.js | B | Active | https://react-aria.adobe.com/TagGroup |
| filters-and-faceted-search | Filters and Faceted Search | Components | React / Next.js | A | Active | https://baymard.com/blog/how-to-design-applied-filters |
| date-pickers-and-calendars | Date Pickers and Calendars | Components | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/examples/datepicker-dialog/ |
| file-upload | File Upload | Components | React / Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file |
| rich-text-editors | Rich Text Editors | Components | React / Next.js | A | Active | https://tiptap.dev/docs/editor/getting-started/install/react |
| sliders-and-range-inputs | Sliders and Range Inputs | Components | React / Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/slider-multithumb/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| WAI-ARIA APG Combobox | https://www.w3.org/WAI/ARIA/apg/patterns/combobox/ | Official | Roles/states, aria-autocomplete modes, keyboard table, aria-activedescendant | Normative popup-input behavior | S | 2026-09-15 |
| WAI-ARIA APG Listbox | https://www.w3.org/WAI/ARIA/apg/patterns/listbox/ | Official | Multi-select keys, aria-selected vs aria-checked | Popup semantics | S | 2026-09-15 |
| WAI-ARIA APG Switch | https://www.w3.org/WAI/ARIA/apg/patterns/switch/ | Official | role=switch, Space/Enter, constant label, no mixed state | Switch semantics | S | 2026-09-15 |
| WAI-ARIA APG Spinbutton | https://www.w3.org/WAI/ARIA/apg/patterns/spinbutton/ | Official | Arrow/Page/Home/End keys, aria-value* | Stepper accessibility | S | 2026-09-15 |
| WAI-ARIA APG Date Picker Dialog | https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/examples/datepicker-dialog/ | Official | Grid keyboard table, roving tabindex, live month heading | Calendar a11y baseline | S | 2026-09-15 |
| WAI-ARIA APG Multi-Thumb Slider | https://www.w3.org/WAI/ARIA/apg/patterns/slider-multithumb/ | Official | Fixed tab order, dynamic min/max, aria-valuetext | Range slider semantics | S | 2026-09-15 |
| WCAG 2.2 SC 2.5.7 Dragging Movements | https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html | Official | Non-drag alternative required | Sliders, dropzones | S | 2026-09-15 |
| WCAG 2.2 SC 3.3.8 Accessible Authentication | https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html | Official | Paste, password managers, cognitive tests | Auth compliance | S | 2026-09-15 |
| W3C WAI Forms Tutorial — Notifications | https://www.w3.org/WAI/tutorials/forms/notifications/ | Official | aria-invalid, aria-describedby, error lists, title updates | Error a11y | A | 2026-09-15 |
| GOV.UK Design System — Validation / Error summary | https://design-system.service.gov.uk/patterns/validation/ | Official | Validate on submit, error summary focus + links, "Error:" title prefix | Research-backed error UX | S | 2026-09-15 |
| GOV.UK Design System — Question pages / Check answers | https://design-system.service.gov.uk/patterns/question-pages/ | Official | One thing per page, back links, check-answers with Change links | Wizard basis | A | 2026-09-15 |
| GOV.UK Design System — Components (text input, button, checkboxes, radios, date input) | https://design-system.service.gov.uk/components/ | Official | No type=number, widths, no disabled buttons, "none" option, date error priority, no auto-tab | Tested field UX | S | 2026-09-15 |
| MDN Constraint validation | https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Constraint_validation | Official | ValidityState, novalidate, :user-invalid | Native validation baseline | A | 2026-09-15 |
| MDN autocomplete attribute | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/autocomplete | Official | Auth/contact/payment tokens, one-time-code, webauthn ordering | Autofill, WCAG 1.3.5 | S | 2026-09-15 |
| MDN button element | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button | Official | type default, formaction, command/commandfor, popovertarget | Button semantics | A | 2026-09-15 |
| MDN input type=file | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file | Official | accept is a hint, capture, multiple | Native upload baseline | S | 2026-09-15 |
| MDN Customizable select | https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Customizable_select | Official | appearance: base-select, selectedcontent, ::picker, fallback | Native styled select | A | 2026-09-15 |
| MDN Web Authentication API | https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API | Official | Conditional mediation, parse*FromJSON, getClientCapabilities, signal* APIs | Passkeys | S | 2026-09-15 |
| Chrome — WebAuthn Conditional Create | https://developer.chrome.com/docs/identity/webauthn-conditional-create | Official | Automatic passkey upgrade, feature detection | Silent passkey enrollment | A | 2026-09-15 |
| MDN WebOTP API | https://developer.mozilla.org/en-US/docs/Web/API/WebOTP_API | Experimental | SMS format, otp transport, limited support | SMS autofill | A | 2026-09-15 |
| web.dev Sign-in form best practices | https://web.dev/articles/sign-in-form-best-practices | Official | Autocomplete, password reveal, separate forms | Password-manager compat | A | 2026-09-15 |
| OWASP File Upload Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html | Official | Server validation, storage, serving | Upload security | S | 2026-09-15 |
| React useActionState | https://react.dev/reference/react/useActionState | Official | Signature, isPending, form reset behavior | Server Action forms | S | 2026-09-15 |
| Zod 4 changelog | https://zod.dev/v4/changelog | Official | `error` param, top-level formats, flattenError, default vs prefault | Shared schema API | S | 2026-09-15 |
| @hookform/resolvers | https://github.com/react-hook-form/resolvers | Open Source | Zod 4 support, input/output generics, standardSchemaResolver | RHF typing | A | 2026-09-15 |
| react-hook-form (type declarations via jsDocs.io) | https://www.jsdocs.io/package/react-hook-form | Open Source | v7.88.0 useForm options/exports (official docs returned 403) | API verification | B | 2026-09-15 |
| shadcn/ui Forms (RHF) | https://ui.shadcn.com/docs/forms/react-hook-form | Open Source | Controller + Field/FieldError, data-invalid | Common composition | A | 2026-09-15 |
| React Aria (ComboBox, TagGroup, NumberField, DatePicker) | https://react-aria.adobe.com/ComboBox | Open Source | Props, virtual focus, formatOptions, @internationalized/date | Most thorough accessible impls | A | 2026-09-15 |
| Base UI (Combobox, NumberField, Checkbox, Slider) | https://base-ui.com/react/components/combobox | Open Source | Parts, chips, onValueCommitted, nested range inputs (v1.8) | Current headless primitives | A | 2026-09-15 |
| Radix Primitives (Select, Switch) | https://www.radix-ui.com/primitives/docs/components/select | Open Source | Hidden native control for forms, positioning modes | Widely used primitives | A | 2026-09-15 |
| Downshift | https://github.com/downshift-js/downshift | Open Source | useCombobox/useSelect/useTagGroup | Headless hooks | A | 2026-09-15 |
| input-otp | https://github.com/guilhermerodz/input-otp | Open Source | Single-input OTP, paste/autofill handling | Correct OTP architecture | A | 2026-09-15 |
| GOV.UK accessible-autocomplete | https://github.com/alphagov/accessible-autocomplete | Open Source | Enhancing native select, debounced status messages | Progressive enhancement model | B | 2026-09-15 |
| React DayPicker changelog | https://daypicker.dev/changelog | Open Source | v10 package rename, removed props | Breaking changes for shadcn Calendar | A | 2026-09-15 |
| react-dropzone | https://github.com/react-dropzone/react-dropzone | Open Source | useDropzone, accept object | Dropzone hook | A | 2026-09-15 |
| Uppy 5.0 announcement | https://uppy.io/blog/uppy-5.0/ | Open Source | Headless components/hooks, breaking changes | Resumable upload stack | A | 2026-09-15 |
| Tiptap 3.0 stable / release notes | https://tiptap.dev/blog/release-notes/tiptap-3-0-is-stable | Official | StarterKit v3, immediatelyRender, useEditorState | Editor API + SSR | A | 2026-09-15 |
| Lexical | https://github.com/facebook/lexical | Open Source | Pre-1.0 (~0.50) status | Version churn risk | A | 2026-09-15 |
| Plate docs | https://platejs.org/docs | Open Source | platejs + @platejs/* packaging | shadcn-aligned editor | B | 2026-09-15 |
| nuqs docs | https://nuqs.dev/docs | Open Source | v2 adapters, useQueryState(s) | URL state for search/filters | B | 2026-09-15 |
| Algolia React InstantSearch RefinementList | https://www.algolia.com/doc/api-reference/widgets/refinement-list/react/ | Open Source | attribute, operator, showMore, searchable | Facet widget reference | B | 2026-09-15 |
| InfoQ — Chrome ships Temporal | https://www.infoq.com/news/2026/02/chrome-temporal-date-api/ | Community | Temporal Stage 4; Chrome 144/Firefox 139; Safari flag | Date modeling | B | 2026-09-15 |
| Baymard — Inline form validation | https://baymard.com/blog/inline-form-validation | Community | Premature errors, remove-on-fix, benchmark stats | Checkout evidence | A | 2026-09-15 |
| Baymard — Applied filters | https://baymard.com/blog/how-to-design-applied-filters | Community | Applied-filter overview placement, individual removal, mobile chips | Filter UX evidence | A | 2026-09-15 |
| NN/g — Form error guidelines / Wizards / Toggle switches / Search suggestions / Filters vs facets | https://www.nngroup.com/articles/errors-forms-design-guidelines/ | Community | Error timing/placement, wizard fit, switch = immediate effect, suggestion UX, facet cost | Research-backed rules | A | 2026-09-15 |
| Adam Silver — The problem with live validation | https://adamsilver.io/blog/the-problem-with-live-validation-and-what-to-do-instead/ | Community | Case for submit-time validation | Expert practitioner view | B | 2026-09-15 |
| a11ysupport.io — datalist | https://a11ysupport.io/tech/html/datalist_element | Community | AT support gaps, zoom issues | Why datalist is not a combobox | B | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Error summary + inline errors | GOV.UK Error summary | W3C WAI notifications, Adam Silver | form-validation-patterns |
| Validation timing | GOV.UK Validation + Baymard | NN/g, Adam Silver | form-validation-patterns |
| Shared Zod schema, client (RHF) + server (Server Action) | Zod 4 + @hookform/resolvers + React useActionState | Conform, TanStack Form | react-hook-form-and-zod (other W07 skills show condensed versions and link here) |
| Numeric entry guidance | GOV.UK Text input | MDN input type=number, web.dev | number-and-currency-inputs |
| Password field primitive vs auth flow | web.dev sign-in best practices | GOV.UK, MDN autocomplete | text-inputs-and-fields (PasswordField); otp-and-auth-forms (flows) |
| Toggle button vs switch | APG Button / Switch | NN/g toggle guidelines | buttons-and-actions (aria-pressed); checkbox-radio-switch (role=switch) |
| Combobox ARIA/keyboard | APG Combobox | React Aria, Base UI, Downshift, GOV.UK autocomplete | select-and-combobox (search-and-autocomplete references it) |
| Multi-select chips | Base UI Combobox Chips | React Aria TagGroup, Downshift useTagGroup | tags-and-chips-input |
| Applied-filter chips | Baymard Applied Filters | — | filters-and-faceted-search (chip semantics in tags-and-chips-input) |
| Command-palette search | — | cmdk, React Aria Autocomplete | Left to command-palette (W06); linked only |
| Calendar keyboard/ARIA | APG Date Picker Dialog | react-day-picker, React Aria docs | date-pickers-and-calendars |
| Slider keyboard/ARIA | APG Slider + Multi-Thumb | Base UI / Radix / React Aria | sliders-and-range-inputs |
| Upload security | OWASP File Upload Cheat Sheet | MDN accept/fakepath notes | file-upload |
| Rich-text HTML sanitization | OWASP XSS Prevention | DOMPurify, sanitize-html | rich-text-editors |

## Gaps

- The shared web-search budget (200 queries) ran out partway through. Remaining checks used WebFetch on primary pages, but some details are unverified:
  - Valibot latest version
  - Downshift latest version and cmdk maintenance status
  - nuqs throttle option naming (`throttleMs` vs `limitUrlUpdates`)
  - Next.js 16 `serverActions.bodySizeLimit` location
  - Tiptap static HTML renderer import path
  - Zod v4 `z.file().mime()` signature
  - react-day-picker v10 CSS subpath
  - Safari/Firefox versions for `appearance: base-select`
  - Baseline status of `command`/`commandfor`, `field-sizing: content` and WebAuthn `uiMode: 'immediate'`
- react-hook-form.com returned 403; RHF options were verified from published type declarations instead.
- No TSX example has been compiled or type-checked. Highest-risk spots:
  - React Aria `FieldError` with external errors
  - Base UI Switch inside `<label>`
  - input-otp `ref`
  - RHF `register` on custom Checkbox (needs ref merge)
  - React Aria ComboBox `selectedKey` vs newer `value` API
- Placeholder helpers (`requireUser`, `renderDocToHtml`, data functions) in the examples must be wired to real code.
- The "RHF feedback on a native `<form action>`" hybrid pattern is a synthesis and has not been tested in a real app.
- Files are 377–560 lines, above the 150–350 target, mainly because every form example is shown twice (RHF + Server Action) after the scope change. Consolidation could move the long dual examples into react-hook-form-and-zod.
- tags-and-chips-input is tier B: there is no APG pattern for tag inputs, and the exact ARIA roles of React Aria TagGroup are undocumented.
- iOS VoiceOver `aria-activedescendant` behavior has not been device-tested. Uppy 5 headless components and BlockNote licensing were not evaluated.
- Not added:
  - `address-and-phone-inputs`: international addresses, libphonenumber, address autocomplete tokens. Only phone basics are covered, in text-inputs-and-fields. Candidate for a future slug.
  - `color-pickers`: not researched because the search budget was gone.
