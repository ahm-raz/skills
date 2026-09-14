# Fintech UI Patterns

## Summary
Frontend patterns for financial products: banking and neobank apps, payments and money movement, investing and trading, lending, expense and treasury tools, and crypto wallets. It covers money display and input, transaction lists, transfer and payment flows with review and confirmation, KYC/onboarding, authentication and step-up (SCA), statements, and regulatory UI obligations (disclosures, fee transparency, audit trails). The security boundaries (PCI DSS scope, token handling, session management) and implementation use React + Next.js.

## Category
Product Patterns

## Subcategories
Money formatting, amount inputs, transaction history, transfers and payouts, KYC onboarding, strong customer authentication, step-up auth, disclosures, statements, fraud messaging, idempotency, session timeouts

## Problem It Solves
Financial UIs carry real consequences. Ambiguous amounts, floating-point rounding, double-submitted transfers, unclear pending vs posted states, hidden fees, and weak session handling all cause monetary loss, regulatory findings, and lost trust. Fintech also has obligations generic SaaS doesn't: SCA in Europe, fee and rate disclosures, accessible statements (the EU EAA covers consumer banking services), and fraud-aware messaging.

## When To Use
- Any UI that displays balances or moves money: wallets, transfers, bill pay, payouts, invoicing, card management, investing, lending applications.
- KYC/KYB onboarding flows.
- Adding step-up authentication for sensitive actions.

## When Not To Use
- Retail checkout for goods: [checkout-flow-design](../checkout-flow-design/Skill.md).
- Charts in trading UIs in depth: [realtime-data-ui](../realtime-data-ui/Skill.md) and [data-visualization-principles](../data-visualization-principles/Skill.md).
- Generic OTP input mechanics: [otp-and-auth-forms](../otp-and-auth-forms/Skill.md).

## Core Principles
1. **Money is never a float.** Represent amounts as integer minor units (or decimal strings) with an ISO 4217 currency code. Format with `Intl.NumberFormat` and the currency's own minor-unit precision.
2. **Every money movement has review → confirm → receipt.** Show amount, recipient, source account, fees, exchange rate, arrival time, and whether it can be cancelled, all before commitment.
3. **Status is explicit and truthful.** Pending, processing, completed, failed, reversed, and scheduled each have distinct labels and explanations. Never show "completed" optimistically.
4. **Idempotent by design.** Each money action carries a client-generated idempotency key, and the UI prevents and survives double-submit.
5. **Step up for risk.** Re-authenticate (passkey/biometric/OTP) for new payees, large amounts, and changes to contact details or security settings.
6. **Disclose, don't bury.** Fees, rates, APR, and risks appear adjacent to the decision, in plain language and at readable size.
7. **Least exposure.** Mask account and card numbers by default, reveal on demand with auth, and time out sessions.

## Best Practices

### Money display
- Always show a currency code or symbol unambiguously. Use the code when multiple currencies share a symbol ("$" for USD/CAD/AUD): `US$1,234.56` or `1,234.56 USD`.
- Right-align amounts in tables with tabular numerals (`font-variant-numeric: tabular-nums`).
- Negative amounts: use a minus sign plus semantic labelling ("Debit"), not red alone.
- Balance types: Available vs Current/Ledger, with an explanation tooltip for the difference.
- Large numbers: compact notation only in overviews ("$1.2M"), full precision on detail.
- Crypto/fractional assets: show meaningful precision and fiat equivalent with the rate timestamp.

### Amount input
- Text input with `inputmode="decimal"`, locale-aware parsing, and currency adornment. Don't use `type="number"`: it has scroll-wheel changes, exponent entry, and locale issues.
- Validate against available balance and limits inline ("You can send up to $2,500 today").
- Show fees and the recipient-gets amount live as the user types, especially for FX.

### Transfer flow anatomy
1. **Recipient:** existing payees (search) or add new (bank details with format validation; name-matching result such as UK Confirmation of Payee / EU Verification of Payee where available).
2. **Amount:** source account, amount, currency, fee, rate (with lock expiry countdown if quoted), arrival estimate.
3. **Review:** all details, editable links back to each field, "Send $500.00" button.
4. **Authenticate:** step-up if required (passkey/biometric/OTP).
5. **Receipt:** status, reference number, timestamp, share/download receipt, cancel window if applicable.

### Transaction history
- Group by date with sticky date headers. Each row shows merchant/counterparty (clean name + logo), category, amount, status badge if not settled.
- Search and filters (date range, amount range, type, account, category). Export CSV/OFX/PDF.
- Detail view: original descriptor, location, card used, reference IDs, dispute/report action, receipts/attachments.

### Onboarding/KYC
- Explain why data is required (regulation) and how it's protected, up front.
- Save progress; allow resume on another device.
- Document capture with provider SDK (quality checks, glare detection), with clear failure reasons and a manual review path.
- Show status ("Verifying, usually under 5 minutes") and notify on completion.

### Fraud and scam messaging
- Before high-risk payments (new payee, large amount, crypto/investment payee type), show friction screens that ask about purpose and warn about common scams, in specific rather than generic language.
- Never pressure; always give an easy "Cancel payment" path.

## Implementation Guidance

### Money type and formatting
```ts
// lib/money.ts
export type Money = { amountMinor: bigint; currency: string }; // ISO 4217

const fractionDigits = (currency: string) =>
  new Intl.NumberFormat("en", { style: "currency", currency }).resolvedOptions().maximumFractionDigits ?? 2;

export function formatMoney(m: Money, locale = "en-US", opts: { display?: "symbol" | "code" | "narrowSymbol" } = {}) {
  const digits = fractionDigits(m.currency);
  const major = Number(m.amountMinor) / 10 ** digits; // display only; never compute with this
  return new Intl.NumberFormat(locale, { style: "currency", currency: m.currency, currencyDisplay: opts.display ?? "symbol" }).format(major);
}

// Parse user input to minor units without floating point
export function parseToMinor(input: string, currency: string, locale = "en-US"): bigint | null {
  const parts = new Intl.NumberFormat(locale).formatToParts(1234.5);
  const group = parts.find(p => p.type === "group")?.value ?? ",";
  const decimal = parts.find(p => p.type === "decimal")?.value ?? ".";
  const normalized = input.replaceAll(group, "").replace(decimal, ".").trim();
  const digits = fractionDigits(currency);
  const re = new RegExp(`^\\d+(\\.\\d{0,${digits}})?$`);
  if (!re.test(normalized)) return null;
  const [whole, frac = ""] = normalized.split(".");
  return BigInt(whole) * 10n ** BigInt(digits) + BigInt(frac.padEnd(digits, "0") || "0");
}
```
(`Number(bigint)` for display is safe for realistic consumer balances. Use a decimal library for very large values or computations.)

### Idempotent transfer (Next.js Server Action)
```ts
"use server";
import { requireSession, requireStepUp } from "@/server/auth";
import { z } from "zod";

const Transfer = z.object({
  idempotencyKey: z.string().uuid(),
  fromAccountId: z.string(), payeeId: z.string(),
  amountMinor: z.string().regex(/^\d+$/), currency: z.string().length(3), quoteId: z.string().optional(),
});

export async function submitTransfer(raw: unknown) {
  const input = Transfer.parse(raw);
  const session = await requireSession();
  await requireStepUp(session, { action: "transfer", amountMinor: BigInt(input.amountMinor) }); // throws → UI prompts auth
  // Core ledger/API enforces ownership, limits, balance, quote validity, and idempotency (unique key per user).
  const result = await ledgerClient.createTransfer({ ...input, userId: session.userId });
  return { status: result.status, reference: result.reference }; // "pending" | "processing" | ...
}
```
The client generates `idempotencyKey` once per review screen (not per click), keeps it through retries, and disables the button while submitting.

### Status model
| Status | Label | UI |
|--------|-------|----|
| `scheduled` | Scheduled for Sep 20 | Cancel available |
| `pending` | Pending | Explain expected time; may still be cancelled |
| `processing` | Processing | No cancel; arrival estimate |
| `completed` | Completed | Receipt |
| `failed` | Failed | Reason + retry/change method; funds returned note |
| `reversed` / `returned` | Returned | Reason + date |

## Recommended Workflow
1. Define money model (minor units, currencies, rounding rules) and share types between server and client.
2. Map each money movement's states and the regulatory disclosures required per jurisdiction (with compliance).
3. Build review/confirm/receipt flow with idempotency and step-up hooks.
4. Build transaction list/detail with truthful statuses, search, export.
5. Integrate KYC provider SDK and onboarding resume.
6. Add session management (idle timeout warning, absolute timeout, device management).
7. Accessibility pass on amounts, statuses, statements (PDFs accessible or HTML alternatives).
8. Test edge cases: FX quote expiry, insufficient funds mid-flow, network retry, double-click, timezone cutoffs.

## Patterns
- **Rate lock countdown:** "Rate guaranteed for 0:45". On expiry, re-quote and require re-review if the amount changed.
- **Masked account number:** `•••• 4821` + "Show" (step-up) with auto re-mask after 30 seconds.
- **Cutoff awareness:** "Sent after 5:00 PM ET arrives next business day".
- **Receipt as shareable artifact:** reference number, timestamp with timezone, counterparty, and amount; PDF generated server-side.
- **Spending limits editor:** slider + numeric input synced, with current usage.
- **Confirmation of Payee result:** match / close match (shows the actual name) / no match, with a strong warning.

## Anti-Patterns
- **Floating-point arithmetic on amounts (`0.1 + 0.2`).** Fix: minor-unit integers or decimal library; server computes.
- **Optimistic "Sent!" before server confirms.** Fix: show "Processing" until an authoritative status arrives.
- **Fee revealed only on the receipt.** Fix: fee and total on the amount and review steps.
- **`type="number"` for money.** Fix: text input + `inputmode="decimal"` + parser.
- **Red/green as the only debit/credit signal.** Fix: sign + label + color.
- **Long-lived sessions on shared devices.** Fix: idle timeout with warning; re-auth for sensitive actions.
- **Account numbers and balances in page titles, URLs, or analytics events.** Fix: IDs only; scrub analytics payloads.
- **Generic scam warnings users click past.** Fix: contextual, specific, and triggered by risk.

## Accessibility
- Amounts read correctly: format text so screen readers speak "minus 45 dollars" (a real minus sign `−` or "-" and currency). Test with VoiceOver/NVDA.
- Error prevention for financial transactions: reversible, checked, or confirmed (WCAG 3.3.4). The review step satisfies "confirmed".
- Timing: rate-lock and session timeouts warn and allow extension where possible (2.2.1), with a live countdown politely announced at meaningful intervals, not every second.
- Accessible authentication (3.3.8): allow password managers, paste in OTP fields, and passkeys.
- Statements: HTML statements or tagged, accessible PDFs.
- Tables of transactions use proper table semantics or list semantics with clear labels.
- EU: the European Accessibility Act covers consumer banking services from 28 June 2025. US: ADA litigation and banking regulators expect WCAG conformance.

## Responsive Design
- Mobile-first: most consumer fintech use is on phones. Put amount entry and the primary action within thumb reach.
- Large, clear amount display on review screens; avoid truncating names or amounts.
- Transaction list: two-line rows (counterparty + category; amount + status) on mobile.
- Keep review details on one scrollable screen, and don't hide fees behind accordions.

## Performance
- Balances and recent transactions server-rendered on dashboard load (no spinner cascade).
- Streaming quotes/prices: throttle UI updates (e.g., 4–10 Hz max) and pause when the tab is hidden.
- Virtualize long transaction histories; paginate server-side by cursor.
- Keep the transfer flow bundle lean; load KYC SDKs only on onboarding routes.

## Security
- Sessions: httpOnly, Secure, SameSite cookies; short idle timeout (e.g., 5–15 min for banking, based on risk assessment); absolute session lifetime; device/session list with revoke.
- Step-up auth with WebAuthn/passkeys preferred. SCA (PSD2) requires two independent factors for most EU/UK customer-initiated electronic payments, with dynamic linking of amount and payee in the authentication.
- Never trust client amounts, balances, limits, or fees. The server/ledger recomputes everything.
- Card data: use issuer-processor or PCI-compliant vault components (iframes) to display full PANs/CVV on "view card details" so card data never touches your origin's JS.
- CSP strict, no third-party scripts on money-movement routes; SRI for vendor SDKs where possible.
- Analytics: scrub PII/financial data; no session replay on sensitive screens (or mask all inputs and text).
- Screenshot/app-switcher privacy: blur sensitive views on `visibilitychange` where appropriate in PWAs.
- Rate-limit and monitor for credential stuffing and account takeover; notify users of new device logins and payee changes.

## Testing
- Money utils: property-based tests for parse/format round trips across currencies (JPY 0 decimals, KWD 3 decimals).
- E2E: transfer happy path; insufficient funds; quote expiry; step-up required; double-click → single transfer; network failure after submit → status reconciliation shows one transfer.
- Authorization: can't view or move money from accounts not owned (IDOR tests).
- Session timeout warning and extension; logout on absolute timeout.
- Accessibility: screen reader reading of amounts and statuses; keyboard-only transfer.

## Tooling
- Money: `dinero.js` (v2), `big.js`/`decimal.js`, native `Intl.NumberFormat`.
- Auth: WebAuthn via SimpleWebAuthn; providers with step-up support (Auth0, Okta, Clerk, Stytch).
- KYC/KYB: Persona, Onfido (Entrust), Veriff, Sumsub, Alloy, Stripe Identity.
- Banking data: Plaid, TrueLayer, Tink, GoCardless (open banking).
- Payments/issuing: Stripe (Treasury/Issuing), Adyen, Marqeta, Lithic, Unit.
- Forms: React Hook Form + Zod with shared schemas.

## Framework Notes
- **Next.js App Router (primary):**
  - All money routes are dynamic; never cache balance or transaction data with `"use cache"` or CDN caching. Set `Cache-Control: private, no-store` on sensitive Route Handler responses.
  - Server Actions for transfers with authorization, step-up check, and idempotency inside the action. Return typed statuses, and use `useActionState` for pending/error UI.
  - Keep financial data in Server Components where possible, so less sensitive data ships to client state.
  - `proxy.ts` can enforce session presence and idle timeout redirects optimistically. Real checks happen in the data layer.
  - Security headers (CSP with nonces, `frame-ancestors 'none'`, `Referrer-Policy: strict-origin-when-cross-origin`) via `proxy.ts` or `next.config.ts` headers.
- **React (Vite SPA):** common for banking web apps behind login. Use a BFF for tokens (no tokens in localStorage), TanStack Query with `gcTime` short for sensitive data, and clear the query cache on logout.

## AI Agent Guidance
- Never use floats for money, `type="number"` for amount inputs, or optimistic "success" for money movement.
- Always add an idempotency key and double-submit protection to money actions.
- Don't implement compliance text yourself as final. Mark disclosures as "requires compliance review".
- Never place real account numbers, card numbers, or credentials in fixtures. Use documented test values from providers.
- Verify before done:
  - [ ] Amounts in minor units with currency; formatting via Intl
  - [ ] Review step shows amount, fees, rate, recipient, arrival, cancelability
  - [ ] Idempotency + disabled submit + status reconciliation after network error
  - [ ] Step-up for sensitive actions; session timeout warning
  - [ ] No sensitive data in URLs, logs, analytics, or caches
  - [ ] Status labels and debits/credits not color-only; screen reader reads amounts correctly

## Examples

```tsx
// Amount input with live fee and recipient amount
"use client";
export function AmountField({ currency, feeBps, maxMinor, onChange }: {
  currency: string; feeBps: number; maxMinor: bigint; onChange: (minor: bigint | null) => void;
}) {
  const [raw, setRaw] = React.useState("");
  const minor = parseToMinor(raw, currency);
  const fee = minor != null ? (minor * BigInt(feeBps)) / 10_000n : null;
  const over = minor != null && minor > maxMinor;
  return (
    <div>
      <label htmlFor="amount">Amount ({currency})</label>
      <input id="amount" inputMode="decimal" autoComplete="off" value={raw}
             aria-invalid={over || (raw !== "" && minor == null)} aria-describedby="amount-help amount-err"
             onChange={e => { setRaw(e.target.value); onChange(parseToMinor(e.target.value, currency)); }} />
      <p id="amount-help">
        {fee != null ? `Fee ${formatMoney({ amountMinor: fee, currency })} · Total ${formatMoney({ amountMinor: minor! + fee, currency })}` : "Enter an amount"}
      </p>
      <p id="amount-err" role="alert">{over ? `You can send up to ${formatMoney({ amountMinor: maxMinor, currency })}` : raw && minor == null ? "Enter a valid amount" : ""}</p>
    </div>
  );
}
```

## Related Skills
- [number-and-currency-inputs](../number-and-currency-inputs/Skill.md) — input mechanics
- [checkout-flow-design](../checkout-flow-design/Skill.md) — card payment boundaries, PCI scope
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — OTP and step-up UI
- [authentication-ux](../authentication-ux/Skill.md) — passkeys, sessions
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — token storage
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — confirmation design
- [accessible-data-tables](../accessible-data-tables/Skill.md) — transaction tables
- [audit-log-interfaces](../audit-log-interfaces/Skill.md) — activity and security logs
- [content-security-policy](../content-security-policy/Skill.md) — script control on sensitive routes

## Sources
- [PCI SSC — SAQ A eligibility FAQ](https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants) — Official — script-attack criterion for embedded payment forms
- [GPayments — 3-D Secure and PSD2 SCA guide (2026)](https://www.gpayments.com/blog/article/3d-secure-and-psd2-strong-customer-authentication-a-guide-for-european-and-uk-psps/) — Community/vendor — SCA, exemptions, PSD3/PSR status
- [European Commission — European Accessibility Act](https://commission.europa.eu/strategy-and-policy/policies/justice-and-fundamental-rights/disability/union-equality-strategy-rights-persons-disabilities-2021-2030/european-accessibility-act_en) — Official — banking services in scope
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — Official — 3.3.4 error prevention (financial), 2.2.1 timing, 3.3.8 accessible authentication
- [MDN — Intl.NumberFormat](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat) — Official — currency formatting
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — Official/Open — idle/absolute timeouts, cookie attributes
- [Stripe Docs — Online payments](https://docs.stripe.com/payments/online-payments) — Official — idempotency and webhook-driven status

## License / Usage Notes
Regulatory references are informational summaries, not legal/compliance advice; confirm obligations per jurisdiction with compliance counsel. Code is original.

## Quality Tier
A — Grounded in PCI SSC, WCAG, OWASP, and payments docs with concrete code for the highest-risk mechanics; regulatory specifics vary by jurisdiction and PSD3/PSR is not yet final.

## Status
Active

## Last Verified
2026-09-15
