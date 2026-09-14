# Healthcare UI Patterns

## Summary
Frontend patterns for healthcare products: patient portals, telehealth, appointment booking, intake forms, clinician-facing EHR-integrated apps (SMART on FHIR), medication and results display, and care coordination tools. It covers safety-critical display rules, patient data privacy in the browser (HIPAA-relevant technical safeguards, tracking technologies), accessibility for diverse and often impaired users, and integration architecture with FHIR APIs. The stack is React + Next.js.

## Category
Product Patterns

## Subcategories
Patient portals, clinician UIs, SMART on FHIR, lab results display, medication lists, appointment scheduling, intake forms, telehealth, PHI privacy, consent, tracking technologies

## Problem It Solves
Healthcare UIs can harm people. Ambiguous units, truncated medication names, mis-selected patients, and alert fatigue all contribute to clinical errors. On the patient side, users are often older, anxious, ill, or have low health literacy or disabilities. Web teams also leak protected health information through analytics pixels, session replay, URLs, and browser caches. This skill encodes safety, privacy, and accessibility rules for building on the web.

## When To Use
- Patient-facing portals, apps, booking, intake, telehealth, results viewing.
- Clinician-facing web apps, especially SMART on FHIR apps launched from EHRs.
- Health-adjacent consumer apps handling sensitive health data (fitness, fertility, mental health), which are covered by consumer health privacy laws even when not HIPAA-covered.

## When Not To Use
- Public marketing site for a clinic (unauthenticated): use [marketing-website-architecture](../marketing-website-architecture/Skill.md), but still apply the tracking-technology section here.
- Medical device software requiring regulatory clearance: this skill informs UI but does not replace IEC 62366 usability engineering or FDA/MDR processes.

## Core Principles
1. **Patient identity is always visible and verified.** In clinician UIs, a persistent patient banner (name, DOB, MRN, sex, allergies) prevents wrong-patient errors.
2. **Clinical data is unambiguous.** Values always carry units, reference ranges, collection time, and source. Never truncate drug names or doses, and avoid dangerous abbreviations.
3. **Privacy by default in the browser.** PHI never goes to third-party trackers, URLs, logs, or shared caches. Authenticated pages carry no marketing pixels.
4. **Plain language for patients.** Explain results and next steps at an accessible reading level, and distinguish "normal", "outside range", and "needs attention" without causing panic.
5. **Accessibility is a clinical requirement.** Users include people with low vision, tremor, cognitive load from illness, and screen reader users. Target WCAG 2.2 AA at minimum. US HHS Section 504 rules require WCAG 2.1 AA for recipients of HHS funding, with compliance dates starting in 2026.
6. **Interoperability through standards.** Use FHIR R4 resources and SMART App Launch for EHR integration; don't screen-scrape.
7. **Alerts are rare and meaningful.** Interruptive alerts are reserved for high-severity, actionable issues to prevent alert fatigue.

## Best Practices

### Patient portal
- Home: upcoming appointments (with prep instructions), messages, new results, outstanding tasks (forms, payments), prescriptions/refills.
- Results: plain-language name, value + unit, reference range, flag (text + icon), trend chart with table alternative, clinician comment, "What does this mean?" link. Consider result release delays and "your provider may contact you" messaging for sensitive results.
- Messaging: set response-time expectations; emergency disclaimer ("If this is an emergency, call 911/112") visible in the composer.
- Proxy access: caregivers/parents switch between patients with an obvious "Viewing: Jane (your child)" indicator.
- Booking: choose reason/visit type → provider/location → time slot (show timezone; telehealth vs in-person) → intake → confirmation with calendar add, directions, and cancellation policy.

### Intake forms
- Save progress automatically; allow resume.
- Ask each question once; prefill from record, with confirmation.
- Sensitive questions (sexual health, mental health, substance use) explain why they're asked and who sees answers; allow "Prefer not to say" where clinically appropriate.
- Medication/allergy entry via searchable terminology (RxNorm/SNOMED-backed) with free-text fallback.

### Clinician UI
- Persistent patient banner; patient switch requires explicit action and shows a confirmation when orders are unsigned.
- Dense but scannable layouts. Clinicians prefer information density; use typography and alignment rather than whitespace to organize.
- Medication display: full generic name (brand in parentheses), strength, dose form, route, frequency, and start/stop dates. Use Tall Man lettering for look-alike names where applicable (e.g., hydrOXYzine vs hydrALAZINE).
- Units: never use a trailing zero ("1.0 mg" can be misread as 10 mg). Always use a leading zero ("0.5 mg"). Avoid "U" for units and "QD"; follow ISMP guidance.
- Timestamps: absolute date/time, 24-hour option, and timezone for telehealth across regions.
- Alerts tiered by severity: interruptive only for critical; others passive/inline.

## Implementation Guidance

### SMART on FHIR app (EHR launch) architecture
1. EHR opens `https://app.example/launch?iss=<fhir-base>&launch=<opaque>`.
2. App discovers `iss/.well-known/smart-configuration`, then redirects to authorize with `launch`, `scope`, `state`, and PKCE (S256 required by SMART App Launch 2.x).
3. Callback exchanges code for tokens **server-side** (BFF). Token response includes patient/encounter context.
4. Browser gets an httpOnly session cookie. FHIR calls go through the BFF or use short-lived tokens held in memory only.

Scopes (SMART v2 syntax): `launch openid fhirUser patient/Patient.rs patient/Observation.rs patient/MedicationRequest.rs`. Request only what the app needs.

```ts
// app/launch/route.ts — Next.js Route Handler (EHR launch start)
import { cookies } from "next/headers";
import { randomBytes, createHash } from "node:crypto";

// Registered EHR FHIR base URLs this app trusts (config, not user input)
const ALLOWED_ISS = (process.env.SMART_ALLOWED_ISS ?? "").split(",").filter(Boolean);

export async function GET(req: Request) {
  const url = new URL(req.url);
  const iss = url.searchParams.get("iss"); const launch = url.searchParams.get("launch");
  if (!iss || !launch || !ALLOWED_ISS.includes(iss)) return new Response("Invalid launch", { status: 400 }); // allowlist FHIR servers
  const config = await fetch(`${iss}/.well-known/smart-configuration`).then(r => r.json());
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const state = randomBytes(24).toString("base64url");
  (await cookies()).set("smart_tx", JSON.stringify({ verifier, state, iss }), { httpOnly: true, secure: true, sameSite: "lax", maxAge: 600, path: "/" });
  // A signed/encrypted cookie or server-side store is preferable to plain JSON in production.
  const auth = new URL(config.authorization_endpoint);
  Object.entries({ response_type: "code", client_id: process.env.SMART_CLIENT_ID!, redirect_uri: `${process.env.APP_URL}/callback`,
    scope: "launch openid fhirUser patient/Patient.rs patient/Observation.rs", state, aud: iss, launch,
    code_challenge: challenge, code_challenge_method: "S256" }).forEach(([k, v]) => auth.searchParams.set(k, v));
  return Response.redirect(auth.toString(), 302);
}
```

### Lab result display model
```ts
type ResultRow = {
  display: string;            // "Hemoglobin A1c"
  value: number | string; unit: string;   // 6.9, "%"
  referenceRange?: { low?: number; high?: number; text?: string };
  interpretation?: "normal" | "low" | "high" | "critical-low" | "critical-high" | "abnormal";
  effectiveAt: string;        // ISO datetime
  status: "preliminary" | "final" | "amended" | "corrected";
};
```
Map from FHIR `Observation.valueQuantity`, `referenceRange`, `interpretation`, `effectiveDateTime`, `status`. Always show preliminary/amended status.

### Tracking technologies decision table
| Page type | Third-party analytics/pixels | Session replay |
|-----------|------------------------------|----------------|
| Authenticated portal, booking, intake, results, messaging | No (unless vendor signs a BAA and configuration is reviewed) | No |
| Unauthenticated pages about specific conditions or booking starts | Minimize; first-party, privacy-preserving analytics; legal review | No |
| General public marketing pages | Consent-gated; review state health privacy laws | Avoid |

Context: a 2024 federal court ruling vacated part of HHS OCR's tracking-technologies bulletin concerning unauthenticated public pages, and OCR withdrew its appeal. HIPAA obligations for authenticated pages and PHI are unchanged. State laws (e.g., Washington's My Health My Data Act) and FTC health breach enforcement can apply beyond HIPAA. Get legal review.

## Recommended Workflow
1. Classify users (patients, proxies, clinicians, staff) and data sensitivity per screen.
2. Decide integration: FHIR APIs via SMART (EHR launch/standalone), or your own backend with BAAs for all vendors touching PHI.
3. Build BFF auth with PKCE, httpOnly sessions, and short idle timeouts appropriate to context (shared clinical workstations vs personal devices).
4. Implement patient banner (clinician) / proxy indicator (patient) and route-level identity context.
5. Build clinical display components (results, meds, allergies, vitals) with unit/range/status rules and a shared terminology layer.
6. Remove third-party scripts from authenticated routes; configure logging to exclude PHI.
7. Accessibility and plain-language review; usability test with representative patients/clinicians.
8. Security review: caching headers, URL contents, error messages, audit logging of PHI access.

## Patterns
- **Patient banner:** sticky header with name, DOB (age), sex, MRN, allergies ("NKDA" spelled out as "No known drug allergies"), and code status where relevant.
- **Result card with trend:** latest value + flag + range bar + sparkline with data-table toggle.
- **Emergency deflection:** in symptom/message flows, red-flag symptom questions route to "Call emergency services" guidance.
- **Proxy switcher:** avatar + name + relationship; color band and text indicator of whose record is open.
- **Appointment prep checklist:** fasting, documents, telehealth device test link.
- **Break-the-glass access:** justification dialog, audit log entry, time-limited access.

## Anti-Patterns
- **PHI in URLs (`/results?name=Jane&test=HIV`).** Leaks into logs, history, and referrers. Fix: opaque IDs; POST bodies; `Referrer-Policy`.
- **Marketing pixels or session replay on portal pages.** Fix: remove; use first-party analytics without PHI under a BAA if needed.
- **Truncated medication names in tables.** Fix: wrap text; never ellipsize clinical identifiers.
- **Red/green-only result flags.** Fix: text labels ("High") + icon + color.
- **Popup alerts for every interaction.** Alert fatigue. Fix: severity tiers; interruptive only for critical.
- **Caching authenticated pages at the CDN or in the browser bfcache with sensitive data after logout.** Fix: `Cache-Control: no-store` on PHI responses; clear client caches on logout.
- **Raw numeric results without units or reference ranges.** Fix: always show both, plus collection time.
- **Tokens in localStorage.** Fix: BFF + httpOnly cookies.

## Accessibility
- WCAG 2.2 AA minimum. In the US, HHS Section 504 regulations adopt WCAG 2.1 AA for web content and apps of HHS-funded entities (larger entities by May 2026, smaller by May 2027). Treat as a legal requirement.
- Plain language and readable typography: body ≥ 16px, line height ~1.5, avoid all caps.
- Target sizes ≥ 24px (2.5.8), preferably 44px for patient apps (tremor, arthritis).
- Charts have data tables; flags conveyed in text.
- Timeouts: warn with extension option (2.2.1). Balance against security on shared devices.
- Forms: explicit labels, grouped questions with `fieldset/legend`, error messages specific to the field; don't rely on placeholder text.
- Telehealth video: captions or live transcription options; keyboard-accessible controls; audio-only fallback.
- Cognitive accessibility: one task per screen for intake, progress indicators, save and resume.

## Responsive Design
- Patient apps are mobile-first (booking, messaging, results on phones).
- Clinician apps target desktop/workstation plus tablet rounds. Test at 1280–1920px dense layouts and 768–1024px tablets.
- Patient banner compresses on narrow screens but never drops name/DOB.
- Zoom to 400% / reflow at 320 CSS px without loss (1.4.10). Many patients use browser zoom.

## Performance
- Patient portals must work on low-end devices and poor connections. Server-render dashboards; keep JS small.
- Telehealth: pre-call device/network test; adaptive bitrate; clear reconnect states.
- FHIR queries: use `_include`/`_revinclude` and `_count` to avoid waterfalls; paginate Bundles; cache terminology lookups (not PHI) aggressively.

## Security
- HIPAA Security Rule technical safeguards (access control, audit controls, integrity, transmission security) implemented across frontend + backend: TLS everywhere, unique user IDs, automatic logoff, audit logs of PHI access.
- BFF pattern: tokens server-side; httpOnly Secure SameSite cookies; PKCE and state validation per SMART App Launch.
- `Cache-Control: no-store` for PHI responses; no PHI in `"use cache"`/ISR/CDN.
- No PHI in client logs, error monitoring breadcrumbs, or analytics. Scrub error reports (Sentry `beforeSend`) and disable default PII capture.
- Business Associate Agreements with any vendor that receives PHI (hosting, email, SMS, error monitoring, video).
- CSP strict; `frame-ancestors` allowlisted to the EHR origins when embedding is required (SMART apps often run in EHR iframes). Otherwise `'none'`.
- Validate `iss` against an allowlist to avoid token exfiltration to malicious FHIR servers.

## Testing
- Unit: unit/range formatting, dangerous abbreviation lint (no trailing zeros), FHIR mapping of Observation/MedicationRequest.
- E2E: SMART launch against a sandbox (SMART Health IT launcher, EHR vendor sandboxes); proxy switching shows correct records; logout clears data (back button shows nothing sensitive).
- Privacy tests: network assertions that authenticated routes make no requests to third-party analytics domains.
- Accessibility: automated + manual screen reader, zoom 400%, keyboard; usability sessions with patients including older adults.
- Security: IDOR tests on patient IDs; caching header assertions.

## Tooling
- FHIR: `fhirclient` (SMART JS client), `@medplum/core` + Medplum React components, HAPI FHIR servers (Java), `@types/fhir`.
- Sandboxes: SMART Health IT App Launcher, Epic/Oracle Health developer sandboxes.
- Terminology: RxNorm APIs (NLM), SNOMED CT (licensed), LOINC.
- Video: HIPAA-eligible SDKs with BAAs (e.g., Twilio, Vonage, Daily; verify BAA availability per plan).
- Analytics: first-party/self-hosted options under BAA, or none on authenticated routes.

## Framework Notes
- **Next.js App Router (primary):**
  - Authenticated route group `(portal)` whose layout loads session server-side and includes no third-party scripts; marketing scripts live only in the `(public)` layout.
  - All PHI routes dynamic; add `Cache-Control: private, no-store` via Route Handler responses and `headers()` config for page routes.
  - SMART launch/callback as Route Handlers; tokens stored server-side (encrypted session store). Server Components fetch FHIR with the server-held token so tokens never reach the client.
  - Opaque IDs in dynamic segments (`/results/[id]`), never names or test types.
  - Error boundaries (`error.tsx`) show generic messages without echoing PHI.
- **React (Vite SPA):** common for SMART apps embedded in EHRs. Use a BFF for token exchange if at all possible. If a pure public client is unavoidable, use PKCE, in-memory tokens, and short lifetimes, and never localStorage.

## AI Agent Guidance
- Treat every patient data field as PHI. Never log it, never send it to analytics, never put it in URLs, and never include it in test fixtures unless the data is synthetic (e.g., Synthea).
- Always render units, ranges, status, and timestamps with clinical values. Don't truncate medication names.
- Don't add third-party scripts to authenticated routes.
- Flag clinical wording and alert logic for clinician review. Don't invent clinical guidance.
- Verify before done:
  - [ ] No PHI in URLs, logs, analytics, error reports, or cached responses
  - [ ] Patient identity visible (banner/proxy indicator)
  - [ ] Clinical values show unit, range, time, status; no trailing zeros
  - [ ] SMART launch uses PKCE S256, state validation, `iss` allowlist
  - [ ] WCAG 2.2 AA checks pass including zoom/reflow and target size
  - [ ] Logout clears sessions and client caches

## Examples

```tsx
// Result row with non-color flag and range
export function ResultRowView({ r }: { r: ResultRow }) {
  const flagText = { normal: "Normal", low: "Low", high: "High", "critical-low": "Critically low", "critical-high": "Critically high", abnormal: "Abnormal" };
  const rr = r.referenceRange;
  const range = rr?.text
    ?? (rr?.low != null && rr?.high != null ? `${rr.low}–${rr.high} ${r.unit}`
      : rr?.high != null ? `below ${rr.high} ${r.unit}`
      : rr?.low != null ? `above ${rr.low} ${r.unit}`
      : "No range provided");
  return (
    <tr>
      <th scope="row">{r.display}{r.status !== "final" && <span className="status"> ({r.status})</span>}</th>
      <td className="num">{r.value} {r.unit}</td>
      <td>{range}</td>
      <td>{r.interpretation ? <span className={`flag flag--${r.interpretation}`}>{flagText[r.interpretation]}</span> : "—"}</td>
      <td><time dateTime={r.effectiveAt}>{new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(r.effectiveAt))}</time></td>
    </tr>
  );
}
```

## Related Skills
- [accessibility-legal-compliance](../accessibility-legal-compliance/Skill.md) — Section 504, ADA, EAA obligations
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — plain language, low cognitive load
- [accessible-data-visualization](../accessible-data-visualization/Skill.md) — result trends
- [accessible-data-tables](../accessible-data-tables/Skill.md) — results and medication tables
- [date-pickers-and-calendars](../date-pickers-and-calendars/Skill.md) — appointment booking
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — intake flows
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — BFF and token storage
- [third-party-script-management](../third-party-script-management/Skill.md) — removing trackers
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — PHI access audit

## Sources
- [HL7 SMART App Launch (current build)](https://build.fhir.org/ig/HL7/smart-app-launch/app-launch.html) — Official — PKCE S256 requirement, state entropy, token storage, EHR vs standalone launch, v2 scopes
- [HIPAA Journal — OCR drops appeal in AHA tracking technology case](https://www.hipaajournal.com/ocr-to-appeal-district-court-ruling-in-aha-tracking-technology-case/) — Community (trade press) — vacatur of the unauthenticated-page portion of OCR's tracking bulletin
- [HHS OCR — Use of Online Tracking Technologies bulletin](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/hipaa-online-tracking/index.html) — Official — remaining guidance on authenticated pages (partially vacated)
- [HHS — Section 504 final rule (web accessibility, WCAG 2.1 AA)](https://www.hhs.gov/civil-rights/for-individuals/disability/section-504-rehabilitation-act-of-1973/index.html) — Official — accessibility requirements and dates
- [ISMP — List of Error-Prone Abbreviations, Symbols, and Dose Designations](https://www.ismp.org/recommendations/error-prone-abbreviations-list) — Official (patient safety org) — trailing/leading zero, abbreviations
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — reflow, target size, timing
- [HL7 FHIR R4 Observation](https://hl7.org/fhir/R4/observation.html) — Official — result data model

## License / Usage Notes
Summaries only; HL7 specifications are freely available under HL7 terms. Regulatory content is informational and not legal advice; HIPAA and state health privacy obligations require counsel. Code original; use synthetic data for testing.

## Quality Tier
A — Strong official grounding (HL7 SMART, WCAG, HHS, ISMP) with concrete implementation; clinical UX specifics should still be validated with clinicians and regulatory counsel per product.

## Status
Active

## Last Verified
2026-09-15
