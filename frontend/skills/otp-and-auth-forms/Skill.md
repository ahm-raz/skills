# OTP and Auth Forms

## Summary
How to build sign-in, sign-up, password reset, passkey, and one-time-code (OTP/2FA) forms in React/Next.js that work with password managers, platform autofill, passkeys (WebAuthn conditional mediation and conditional create), and SMS code autofill, and that meet WCAG 2.2 Accessible Authentication. Covers the form and component layer with shared Zod schemas used by React Hook Form and Server Actions. Journey design lives in authentication-ux, and session handling in frontend-auth-token-handling / nextjs-authentication.

## Category
Components

## Subcategories
sign-in form, sign-up form, password field, passkeys, WebAuthn, conditional UI, conditional create, OTP input, WebOTP, one-time-code, magic link, 2FA, password reset

## Problem It Solves
Auth forms get a lot of traffic and break easily. Password managers can't fill them, six separate OTP boxes break paste and SMS autofill, passkeys never show up in autofill, paste is blocked (failing WCAG 3.3.8), error messages reveal whether an account exists, and client-only validation leaves Server Actions open to junk input. Small markup mistakes directly cost conversion and security.

## When To Use
- Building sign-in, sign-up, reset, or verify screens.
- Adding passkeys to an existing password flow.
- Building an OTP / verification code input.

## When Not To Use
- Choosing auth methods and journeys: [authentication-ux](../authentication-ux/Skill.md).
- Cookies, sessions, tokens, CSRF: [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md).
- Auth library setup (Auth.js, Better Auth, Clerk) and route protection: [nextjs-authentication](../nextjs-authentication/Skill.md).

## Core Principles
1. Let the browser and password manager do the work: correct `autoComplete`, `name`, `id`, `type`, and one `<form>` per purpose.
2. Treat passkeys as first-class: show them in autofill (conditional mediation) and upgrade password users silently (conditional create) where supported.
3. An OTP is one input with `autoComplete="one-time-code"`, not N inputs.
4. Never block paste, autofill, or show-password (WCAG 3.3.8).
5. Don't reveal whether an account exists through error messages.
6. Every auth Server Action or route handler validates again with the shared schema and is rate-limited.
7. SMS OTP is a weak factor. Prefer passkeys and authenticator apps, and keep SMS as a fallback.

## Best Practices
- Identifier field: `autoComplete="username webauthn"` (`webauthn` must be the last token) so passkeys appear in autofill. Use `type="email"` if it's an email.
- Password: `current-password` on sign-in, `new-password` on sign-up and reset. Include a show-password toggle and no confirm-password field.
- Use different `id`/`name` values for sign-in and sign-up fields, and give each its own `<form>`.
- Identifier-first (email, then password or code) is fine. On step 2, keep a hidden username field (`autoComplete="username"` with the value) so managers save the right pair.
- New passwords: show the rules up front and check them live as the user types. Allow long passphrases: NIST SP 800-63B says at least 8 characters minimum, allow at least 64, no composition rules, and check breached-password lists on the server.
- OTP: `inputMode="numeric"`, `autoComplete="one-time-code"`, a digit pattern if codes are digits only, `maxLength` equal to the code length. Auto-submit on completion is optional; if you use it, keep the value and focus after an error.
- Say where the code went ("Enter the 6-digit code we sent to •••• 4821"). Offer resend with a visible cooldown and a way to change the destination.
- End the SMS with `@your-domain #123456` (origin-bound). This enables WebOTP on Chrome Android and improves iOS suggestions.
- Errors: "Incorrect email or password". For reset, say "If an account exists, we've sent an email".
- Put "Forgot your password?" next to the password field.
- Magic links: also include a code in the email for when the user opens it on a different device.

## Implementation Guidance

### Autocomplete map
| Screen | Field | Attributes |
|---|---|---|
| Sign in | Email/username | `type="email" name="email" autoComplete="username webauthn"` |
| Sign in | Password | `type="password" autoComplete="current-password"` |
| Sign up | Email | `autoComplete="username"` |
| Sign up / reset | New password | `autoComplete="new-password"` |
| Verify | Code | `type="text" inputMode="numeric" autoComplete="one-time-code"` |
| Change password | Current + new | `current-password` + `new-password` + hidden `username` |

### Passkey sign-in with conditional mediation
- Start `navigator.credentials.get({ publicKey, mediation: 'conditional', signal })` when the sign-in page mounts. Check `PublicKeyCredential.isConditionalMediationAvailable()` first.
- Leave out `allowCredentials`; conditional mediation only offers discoverable credentials.
- Use `PublicKeyCredential.parseRequestOptionsFromJSON()` for server JSON and `credential.toJSON()` for the response. Both are now broadly available; `@simplewebauthn/browser` is the fallback.
- Abort the conditional request before starting a modal one (the "Sign in with a passkey" button). Only one WebAuthn request can be pending.
- If the server doesn't recognize the credential, call `PublicKeyCredential.signalUnknownCredential({ rpId, credentialId })` so the provider hides it.
- After sign-in, call `signalAllAcceptedCredentials`; after a profile rename, call `signalCurrentUserDetails`. Feature-detect each one.
- `uiMode: 'immediate'` (it replaced the earlier `mediation: 'immediate'` proposal) is still experimental. Don't depend on it.

### Passkey auto-upgrade (conditional create)
After a successful password sign-in, call `navigator.credentials.create({ publicKey, mediation: 'conditional' })`. Feature-detect with `(await PublicKeyCredential.getClientCapabilities()).conditionalCreate`. As of mid-2026 it's supported in Chrome with Google Password Manager (desktop, and Android on recent versions) and Safari 18+ / iOS 18+ with Apple Passwords. Silently ignore `InvalidStateError`, `NotAllowedError`, and `AbortError`.

### WebOTP (Chromium on Android; progressive enhancement)
`navigator.credentials.get({ otp: { transport: ['sms'] }, signal })` resolves with `{ code }`. Abort on submit, on unmount, and after a timeout. Cross-origin iframes need `allow="otp-credentials"`. Safari relies on `autoComplete="one-time-code"` suggestions instead.

### OTP input architecture
One real `<input>` holds the whole code, and the boxes are purely visual (the `input-otp` approach used by shadcn/ui `InputOTP`). That keeps paste, SMS/email autofill, password-manager fill, undo, selection, and screen-reader reading working. Keyboard behavior is a normal text field: typing moves forward, Backspace deletes, arrows move the caret, Ctrl/Cmd+V pastes the whole code, Enter submits.

## Recommended Workflow
1. Decide the methods (passkey, password, OTP, magic link) with product and security.
2. Write shared Zod schemas (`signInSchema`, `otpSchema`) in plain modules.
3. Build semantic forms from the autocomplete map; one `<form>` per purpose.
4. Add the show-password toggle; remove confirm-password and any paste blocking.
5. Wire both submission paths as needed: Server Action + `useActionState`, or React Hook Form + `zodResolver` calling the action. The action always runs `safeParse`, rate-limits, and returns generic errors.
6. Add passkey conditional mediation (with abort), an explicit passkey button, and conditional create after password sign-in.
7. Build the OTP step: single input, resend cooldown, masked destination, WebOTP enhancement, origin-bound SMS.
8. Test with Chrome/Google Password Manager, Safari/iCloud Keychain, 1Password, Bitwarden, iOS SMS autofill, Android WebOTP, and screen readers.

## Patterns
- **Identifier-first**: step 1 is the identifier (with passkey autofill); step 2 is password or OTP with a hidden username field.
- **Single-input OTP with slots**: a transparent input over the slot boxes; `onComplete` → `form.requestSubmit()`.
- **Resend cooldown**: the button has `aria-disabled` and shows "Resend code in 0:30". Announce only when it becomes available.
- **Password rules checklist**: a list linked through `aria-describedby`, updated as the user types. Announce a summary on blur, not on every keystroke.
- **Passkey enrollment prompt**: where conditional create isn't supported, show a one-time "Create a passkey" screen after sign-in that can be dismissed.
- **Step-up re-auth**: for sensitive actions, ask for a passkey with `userVerification: 'required'` or an OTP in a dialog.

## Anti-Patterns
- **Six separate OTP inputs**: breaks paste, autofill, and screen-reader reading. Fix: one input with visual slots.
- **Blocking paste** on password or OTP: fails SC 3.3.8. Fix: allow it.
- **`autoComplete="off"`** on login: managers ignore it and users suffer. Fix: the right tokens.
- **Confirm-password field**. Fix: one field + show toggle.
- **Password step without a hidden username**: managers save the wrong credentials. Fix: a hidden `autoComplete="username"` input.
- **Modal `credentials.get` on page load**: an unexpected OS dialog. Fix: conditional mediation on load, modal only from a button.
- **Not aborting the conditional request** in effect cleanup: React Strict Mode creates two pending requests and the second one errors. Fix: `AbortController` in cleanup.
- **"No account found for this email"**: lets attackers enumerate accounts. Fix: a generic message.
- **Returning the password in `useActionState` state** so it can be re-filled. Fix: return only the email.
- **Validation only in RHF**: the Server Action accepts anything posted to it. Fix: `safeParse` in the action.
- **CAPTCHAs that require typing characters as the only path**: fails SC 3.3.8. Fix: risk-based or invisible challenges, or an alternative.
- **Auto-submit that wipes the code after an error**. Fix: keep the value, show the error, keep focus.

## Accessibility
- SC 3.3.8 Accessible Authentication (Minimum, AA): no cognitive-function test without an alternative. Support paste and password managers. Passkeys and magic links count as compliant alternatives.
- SC 1.3.5: autocomplete tokens.
- OTP: one label ("Verification code") and a hint giving the length and where the code was sent. Visual slots are `aria-hidden`.
- The show-password toggle is `type="button"` with a clear name, and focus stays put when it's pressed.
- On a failed submit, announce errors (focus the first invalid field or an error summary).
- SC 2.2.1 Timing Adjustable: expiring codes can be resent. Don't announce the countdown every second.
- Multi-step flows: move focus to the new step's heading or first field.

## Responsive Design
- Single column, 16px inputs, and a submit button that stays visible above the virtual keyboard.
- Six 44px OTP slots plus gaps must fit at 320px wide; shrink the gaps if needed.
- `enterKeyHint="next"` on the identifier and `"go"` on the last field.

## Performance
- Start conditional mediation early (on mount) so passkey autofill is ready when the user focuses the field.
- Load bot-detection and analytics scripts after the form renders; never let them block the sign-in page.
- Server Action forms submit before hydration, so users on slow devices can still sign in.

## Security
- Generate WebAuthn challenges on the server, single-use and short-lived. Verify origin and rpId with a vetted library (SimpleWebAuthn server).
- Rate-limit sign-in, OTP verification, and resend per account and per IP. Lock OTPs after N attempts. Use at least 6 digits and expiry measured in minutes.
- Never put OTPs or passwords in URLs, logs, analytics, or session replay.
- SMS is exposed to SIM swap and phishing; passkeys resist phishing.
- Set session cookies on the server only (`httpOnly`, `secure`, `sameSite`). Call `redirect()` after success. Next.js checks Origin for Server Actions; configure `serverActions.allowedOrigins` behind proxies.
- Serve auth routes with a strict CSP and `frame-ancestors 'none'`.
- Magic links: single use, short expiry, tied to the requesting session where possible.

## Testing
- Schema unit tests: invalid emails, empty password, codes with spaces or letters.
- Server Action tests: call with `FormData`; unknown user and wrong password return identical responses; `values` never contains the password; rate limiter triggers.
- Component tests: pasting "123456" fills the OTP; the error keeps focus; `autoComplete` / `inputMode` attributes are present.
- Playwright: Chromium CDP virtual authenticator (`WebAuthn.enable`, `WebAuthn.addVirtualAuthenticator` with `hasResidentKey`, `hasUserVerification`, `isUserVerified`) for passkey registration and sign-in.
- Manual matrix: iOS Safari code suggestion, Android Chrome WebOTP, passkey autofill in Chrome and Safari, 1Password and Bitwarden.
- axe plus a screen reader pass on every step.

## Tooling
- `input-otp` (single-input OTP; basis of shadcn/ui `InputOTP`). Active.
- `@simplewebauthn/browser` + `@simplewebauthn/server`. Active.
- Better Auth, Auth.js, Clerk, Auth0, Stytch, Corbado: passkey-capable. Check that they use conditional UI and conditional create.
- React Hook Form + `@hookform/resolvers` + Zod 4. Active.
- Have I Been Pwned Pwned Passwords k-anonymity API for breached-password checks (server side).
- Rate limiting: Upstash Ratelimit, or your platform's WAF.

## Framework Notes
- **React (Vite SPA)**: React Hook Form + `zodResolver` posting to your auth API. The API imports the same schema, validates again, rate-limits, and sets `httpOnly` cookies. Start passkey conditional mediation in `useEffect` with `AbortController` cleanup (Strict Mode double-invokes effects in development). Without SSR the form appears only after the JS bundle loads, so keep the auth route small and in the first chunk.
- **Next.js (App Router)**: sign-in and OTP verification as Server Actions (`'use server'`) with `useActionState` (works before hydration) and `useFormStatus` in the submit button. WebAuthn options and verification endpoints fit route handlers (`app/api/webauthn/.../route.ts`) that return JSON. Call `redirect()` after success, which works both from `<form action>` and when RHF calls the action inside `handleSubmit`. Keep the auth pages dynamic and never cache responses that include user data.

## AI Agent Guidance
- Do: follow the autocomplete map exactly; use one input for OTP; put `username webauthn` on the identifier; start conditional mediation with abort cleanup; share Zod schemas between client and server; `safeParse` + rate-limit in every action; return generic errors; allow paste.
- Don't: build multi-box OTP from scratch, add confirm-password, disable autofill, open modal WebAuthn on load, return or log passwords, trust client validation, or call SMS strong 2FA.
- Verify before done: inspect the rendered attributes; paste a code; run the Playwright virtual-authenticator passkey test; confirm unknown-user and wrong-password responses are identical; confirm the Server Action rejects a malformed `FormData` posted directly; axe passes; the whole flow works by keyboard alone.

## Examples
```tsx
// app/(auth)/schema.ts — shared by RHF clients and Server Actions (no directive)
import { z } from 'zod';

export const signInSchema = z.object({
  email: z.email('Enter an email address in the correct format, like name@example.com'),
  password: z.string().min(1, 'Enter your password').max(1024),
});
export type SignInInput = z.infer<typeof signInSchema>;

export const otpSchema = z.object({
  code: z
    .string()
    .transform((s) => s.replace(/\s/g, ''))
    .pipe(z.string().regex(/^\d{6}$/, 'Enter the 6-digit code')),
});
export type OtpInput = z.input<typeof otpSchema>;

export type AuthState = {
  ok: boolean;
  formError?: string;
  errors?: Record<string, string[] | undefined>;
  values?: { email?: string };                     // never include password or code
};
```

```tsx
// app/(auth)/actions.ts
'use server';
import { z } from 'zod';
import { redirect } from 'next/navigation';
import { headers } from 'next/headers';
import { signInSchema, otpSchema, type AuthState } from './schema';
import { verifyPassword, startOtpChallenge, verifyOtp, rateLimit } from '@/lib/server/auth';

const GENERIC = 'Incorrect email or password';

async function signInCore(input: unknown): Promise<AuthState> {
  const parsed = signInSchema.safeParse(input);            // server re-validates
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  const ip = (await headers()).get('x-forwarded-for') ?? 'unknown';
  if (!(await rateLimit(`signin:${parsed.data.email}:${ip}`))) {
    return { ok: false, formError: 'Too many attempts. Wait 15 minutes and try again.' };
  }
  const user = await verifyPassword(parsed.data.email, parsed.data.password);
  if (!user) return { ok: false, formError: GENERIC };       // same message for unknown user
  await startOtpChallenge(user);                             // sends SMS/email, sets pending-2FA cookie
  redirect('/verify');
}

export async function signInAction(_prev: AuthState, formData: FormData): Promise<AuthState> {
  const email = String(formData.get('email') ?? '');
  const result = await signInCore({ email, password: String(formData.get('password') ?? '') });
  return { ...result, values: { email } };
}

export async function signIn(input: unknown): Promise<AuthState> {
  return signInCore(input);
}

async function verifyCore(input: unknown): Promise<AuthState> {
  const parsed = otpSchema.safeParse(input);
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  const ok = await verifyOtp(parsed.data.code);              // attempt counter + expiry on server
  if (!ok) return { ok: false, errors: { code: ['The code is incorrect or has expired'] } };
  redirect('/app');
}

export async function verifyOtpAction(_prev: AuthState, formData: FormData): Promise<AuthState> {
  return verifyCore({ code: String(formData.get('code') ?? '') });
}

export async function verifyOtpRHF(input: unknown): Promise<AuthState> {
  return verifyCore(input);
}
```

```tsx
// lib/server/sms.ts — origin-bound OTP message (enables WebOTP / better iOS suggestions)
export function buildOtpSms(code: string, host: string) {
  return `Your Example sign-in code is ${code}. Don't share it.\n\n@${host} #${code}`;
}
```

```tsx
// app/(auth)/sign-in/use-passkey-autofill.ts — conditional mediation with abort cleanup
'use client';
import { useEffect } from 'react';

export function usePasskeyAutofill(onSignedIn: () => void) {
  useEffect(() => {
    const ac = new AbortController();
    (async () => {
      if (!window.PublicKeyCredential?.isConditionalMediationAvailable) return;
      if (!(await PublicKeyCredential.isConditionalMediationAvailable())) return;
      const optionsJSON = await fetch('/api/webauthn/authenticate/options', { signal: ac.signal }).then((r) => r.json());
      const publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(optionsJSON);
      try {
        const cred = (await navigator.credentials.get({ publicKey, mediation: 'conditional', signal: ac.signal })) as PublicKeyCredential | null;
        if (!cred) return;
        const res = await fetch('/api/webauthn/authenticate/verify', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(cred.toJSON()),
          signal: ac.signal,
        });
        if (res.ok) onSignedIn();
        else if (res.status === 404 && 'signalUnknownCredential' in PublicKeyCredential) {
          await PublicKeyCredential.signalUnknownCredential({ rpId: location.hostname, credentialId: cred.id });
        }
      } catch (e) {
        if ((e as DOMException).name !== 'AbortError') console.warn('Passkey autofill failed', e);
      }
    })();
    return () => ac.abort();                              // Strict Mode + unmount safety
  }, [onSignedIn]);
}
```

```tsx
// app/(auth)/sign-in/sign-in-form-action.tsx — Server Action + useActionState + useFormStatus
'use client';
import { useActionState } from 'react';
import { useRouter } from 'next/navigation';
import { signInAction } from '../actions';
import type { AuthState } from '../schema';
import { usePasskeyAutofill } from './use-passkey-autofill';
import { TextField } from '@/components/ui/text-field';
import { PasswordField } from '@/components/ui/password-field';
import { SubmitButton } from '@/components/ui/submit-button';

export function SignInFormAction() {
  const router = useRouter();
  const [state, formAction] = useActionState<AuthState, FormData>(signInAction, { ok: false });
  usePasskeyAutofill(() => router.replace('/app'));

  return (
    <form action={formAction} noValidate className="grid max-w-sm gap-6">
      {state.formError && <p role="alert" className="text-red-700">{state.formError}</p>}
      <TextField label="Email address" id="signin-email" name="email" type="email"
        autoComplete="username webauthn" spellCheck={false} autoCapitalize="none" enterKeyHint="next"
        defaultValue={state.values?.email} error={state.errors?.email?.[0]} />
      <PasswordField id="signin-password" name="password" autoComplete="current-password"
        error={state.errors?.password?.[0]} />
      <a href="/forgot-password">Forgot your password?</a>
      <SubmitButton pendingLabel="Signing in…">Sign in</SubmitButton>
    </form>
  );
}
```

```tsx
// app/(auth)/sign-in/sign-in-form-rhf.tsx — React Hook Form + Zod calling the same server code
'use client';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'next/navigation';
import { signInSchema, type SignInInput } from '../schema';
import { signIn } from '../actions';
import { usePasskeyAutofill } from './use-passkey-autofill';
import { TextField } from '@/components/ui/text-field';
import { PasswordField } from '@/components/ui/password-field';
import { Button } from '@/components/ui/button';

export function SignInFormRHF() {
  const router = useRouter();
  usePasskeyAutofill(() => router.replace('/app'));
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm<SignInInput>({
    resolver: zodResolver(signInSchema),
    mode: 'onSubmit',
  });

  const onSubmit = handleSubmit(async (values) => {
    const res = await signIn(values);                     // redirect() on success is handled by Next.js
    if (res.formError) setError('root.server', { message: res.formError });
    if (res.errors?.email?.[0]) setError('email', { message: res.errors.email[0] });
  });

  return (
    <form onSubmit={onSubmit} noValidate className="grid max-w-sm gap-6">
      {errors.root?.server && <p role="alert" className="text-red-700">{errors.root.server.message}</p>}
      <TextField label="Email address" type="email" autoComplete="username webauthn" spellCheck={false}
        autoCapitalize="none" {...register('email')} error={errors.email?.message} />
      <PasswordField autoComplete="current-password" {...register('password')} error={errors.password?.message} />
      <a href="/forgot-password">Forgot your password?</a>
      <Button type="submit" pending={isSubmitting}>{isSubmitting ? 'Signing in…' : 'Sign in'}</Button>
    </form>
  );
}
```

```tsx
// app/(auth)/verify/otp-field.tsx — single real input, visual slots, WebOTP enhancement
'use client';
import { useEffect } from 'react';
import { OTPInput, REGEXP_ONLY_DIGITS } from 'input-otp';

type OtpFieldProps = {
  name?: string; value?: string; onChange?: (v: string) => void; onComplete?: (v: string) => void;
  error?: string; destination: string; inputRef?: React.Ref<HTMLInputElement>;
};

export function OtpField({ name = 'code', value, onChange, onComplete, error, destination, inputRef }: OtpFieldProps) {
  useEffect(() => {                                        // WebOTP: Chromium Android only
    if (!('OTPCredential' in window)) return;
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 60_000);
    navigator.credentials
      .get({ otp: { transport: ['sms'] }, signal: ac.signal } as CredentialRequestOptions)
      .then((otp) => { const code = (otp as unknown as { code: string }).code; onChange?.(code); onComplete?.(code); })
      .catch(() => {});
    return () => { clearTimeout(t); ac.abort(); };
  }, [onChange, onComplete]);

  return (
    <div className="grid gap-1">
      <label htmlFor="otp">Verification code</label>
      <p id="otp-hint">Enter the 6-digit code we sent to {destination}</p>
      {error && <p id="otp-error" className="text-red-700"><span className="sr-only">Error: </span>{error}</p>}
      <OTPInput
        ref={inputRef}
        id="otp"
        name={name}
        maxLength={6}
        pattern={REGEXP_ONLY_DIGITS}
        inputMode="numeric"
        autoComplete="one-time-code"
        aria-describedby={error ? 'otp-hint otp-error' : 'otp-hint'}
        aria-invalid={error ? true : undefined}
        {...(value !== undefined ? { value, onChange } : {})}
        onComplete={onComplete}
        containerClassName="flex gap-2"
        render={({ slots }) => (
          <>
            {slots.map((slot, i) => (
              <div key={i} aria-hidden="true"
                className={`grid size-11 place-items-center rounded border-2 text-lg ${slot.isActive ? 'outline-3' : ''}`}>
                {slot.char ?? (slot.hasFakeCaret ? '|' : '')}
              </div>
            ))}
          </>
        )}
      />
    </div>
  );
}
```

```tsx
// app/(auth)/verify/verify-forms.tsx — OTP both ways with the shared otpSchema
'use client';
import { useActionState, useRef } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { otpSchema, type OtpInput, type AuthState } from '../schema';
import { verifyOtpAction, verifyOtpRHF } from '../actions';
import { OtpField } from './otp-field';
import { SubmitButton } from '@/components/ui/submit-button';
import { Button } from '@/components/ui/button';

export function VerifyFormAction({ destination }: { destination: string }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction] = useActionState<AuthState, FormData>(verifyOtpAction, { ok: false });
  return (
    <form ref={formRef} action={formAction} noValidate className="grid gap-6">
      <OtpField destination={destination} error={state.errors?.code?.[0]}
        onComplete={() => formRef.current?.requestSubmit()} />
      <SubmitButton pendingLabel="Checking…">Continue</SubmitButton>
    </form>
  );
}

export function VerifyFormRHF({ destination }: { destination: string }) {
  const { control, handleSubmit, setError, formState: { isSubmitting } } = useForm<OtpInput>({
    resolver: zodResolver(otpSchema),
    defaultValues: { code: '' },
  });
  const onSubmit = handleSubmit(async (values) => {
    const res = await verifyOtpRHF(values);              // server re-validates and redirects on success
    const msg = res.errors?.code?.[0];
    if (msg) setError('code', { message: msg }, { shouldFocus: true });
  });
  return (
    <form onSubmit={onSubmit} noValidate className="grid gap-6">
      <Controller control={control} name="code" render={({ field, fieldState }) => (
        <OtpField destination={destination} name={field.name} value={field.value} onChange={field.onChange}
          inputRef={field.ref} error={fieldState.error?.message} onComplete={() => onSubmit()} />
      )} />
      <Button type="submit" pending={isSubmitting}>{isSubmitting ? 'Checking…' : 'Continue'}</Button>
    </form>
  );
}
```

## Related Skills
- [authentication-ux](../authentication-ux/Skill.md) — choosing methods and journeys
- [nextjs-authentication](../nextjs-authentication/Skill.md) — auth libraries, sessions, route protection
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — cookies and tokens
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — action security model
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — schema-driven client validation
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — effects with AbortController for browser APIs
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — TextField and PasswordField primitives
- [form-validation-patterns](../form-validation-patterns/Skill.md) — error timing and summaries
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — enumeration, CSP
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — SC 3.3.8 and 3.3.7
- [multi-step-forms-and-wizards](../multi-step-forms-and-wizards/Skill.md) — identifier-first steps

## Sources
- [MDN: Web Authentication API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API) — Official — conditional mediation, JSON helpers, getClientCapabilities, signal APIs
- [Chrome for Developers: Conditional create](https://developer.chrome.com/docs/identity/webauthn-conditional-create) — Official — automatic passkey upgrade, detection, errors
- [MDN: WebOTP API](https://developer.mozilla.org/en-US/docs/Web/API/WebOTP_API) — Official — SMS format, API, permissions policy, support
- [MDN: autocomplete attribute](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/autocomplete) — Official — username, current/new-password, one-time-code, webauthn
- [web.dev: Sign-in form best practices](https://web.dev/articles/sign-in-form-best-practices) — Official — form structure, password reveal, separate forms
- [WCAG 2.2 Understanding 3.3.8 Accessible Authentication](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html) — Official — paste, managers, CAPTCHAs
- [input-otp (GitHub)](https://github.com/guilhermerodz/input-otp) — Open Source — single-input OTP architecture
- [Corbado: WebAuthn immediate mediation](https://www.corbado.com/blog/webauthn-immediate-mediation) — Community — uiMode change, experimental status
- [Next.js docs: Authentication guide](https://nextjs.org/docs/app/guides/authentication) — Official — Server Action sign-in pattern, redirect
- NIST SP 800-63B — Official — password length and composition guidance

## License / Usage Notes
Summarized from W3C (W3C license), MDN (CC-BY-SA), Chrome docs (CC-BY 4.0), Next.js docs, input-otp (MIT), SimpleWebAuthn (MIT). All code examples are original. Browser support for passkey features changes often, so re-check it.

## Quality Tier
A — official WebAuthn, WebOTP, and WCAG sources checked for 2026, with complete dual-stack examples; passkey browser support moves quickly and immediate mediation is experimental.

## Status
Active

## Last Verified
2026-09-15
