# Authentication UX

## Summary
User experience of sign-up, sign-in, passkeys, social/SSO login, magic links, one-time codes, MFA, password reset, session expiry, and account recovery — balancing security, accessibility (WCAG 2.2 SC 3.3.8 Accessible Authentication) and conversion. Includes passkey conditional UI ("autofill") implementation, form attributes that make password managers work, and Next.js patterns.

## Category
UX

## Subcategories
sign-in, sign-up, passkeys/WebAuthn, SSO, magic links, OTP, MFA, password reset, account recovery, session timeout, identifier-first login

## Problem It Solves
Authentication is the gate to all value, yet it is often the most frustrating flow: forced complex passwords, blocked paste, CAPTCHAs, confusing "Sign in vs Sign up", lost sessions mid-task, and recovery dead ends. These cause lockouts, abandonment, support load, and accessibility failures.

## When To Use
- Designing or refactoring any login/signup/recovery flow.
- Adding passkeys, SSO, or MFA.
- Auditing for WCAG 2.2 3.3.8 compliance.

## When Not To Use
- Backend protocol/token implementation details (see auth token handling and Next.js auth skills); this skill focuses on UX.

## Core Principles
1. **Minimize cognitive tests** (3.3.8): no memorization or transcription without alternatives — support password managers, paste, passkeys, magic links, SSO.
2. **Offer passkeys as the preferred method** where possible; keep a fallback.
3. **Clear, separate entry points**: "Sign in" and "Create account" clearly labeled; recover gracefully when users choose wrong.
4. **Ask only for what's needed** at signup; defer profile details.
5. **Preserve context**: return users to where they were after auth (safe redirect).
6. **Don't leak account existence** while still being helpful.
7. **Security friction is proportional**: step-up auth for sensitive actions, not on every visit.
8. **Recovery is part of the design**, not an afterthought.

## Best Practices
- Identifier-first flow: email/username first, then route to passkey, SSO (by domain), or password.
- Use `autocomplete="username webauthn"` on the identifier field for passkey autofill; `current-password` / `new-password` on password fields; `one-time-code` for OTP.
- Allow paste into all fields; provide "Show password" toggle; no password confirmation field.
- Password rules: minimum length (NIST SP 800-63B: at least 8, recommend 15+ when password is the only factor), no composition rules, check against breached password lists, show requirements before typing.
- Magic links/OTP: explain where the code was sent, allow resend with cooldown timer, codes valid for reasonable time, one input field (not 6 separate boxes unless fully accessible with paste support).
- SSO buttons: use provider names ("Continue with Google"); don't make SSO the only visible option if email is supported.
- MFA: offer passkeys/authenticator apps over SMS; provide recovery codes; "Remember this device" option.
- Errors: "Email or password is incorrect" (no enumeration); lockout messages state when they can retry.
- Password reset: always show "If an account exists for x@y.com, we've sent a link" and what to do if no email arrives.
- Session expiry: warn before timeout with option to extend (2.2.1); on expiry, re-auth in a dialog or redirect with return URL and preserve unsaved data.
- Avoid CAPTCHAs; use risk-based bot detection, rate limiting, and invisible challenges; if a challenge is needed, provide an accessible non-cognitive alternative.
- After passkey-less sign-in, offer to create a passkey (conditional create where supported).

## Implementation Guidance

Method selection:

| Context | Primary | Fallback |
|---|---|---|
| Consumer web app | Passkey + email magic link/OTP | Password (optional), social |
| B2B SaaS | SSO (SAML/OIDC by email domain) + passkey | Email OTP |
| High-security (fintech) | Passkey + step-up for sensitive actions | Authenticator app, recovery codes |
| Internal tools | Company SSO | None |
| Low-stakes content | Social or magic link | — |

WCAG 3.3.8 compliance quick check:
- [ ] Password fields allow paste and autofill (correct `autocomplete`).
- [ ] OTP input allows paste and `autocomplete="one-time-code"`.
- [ ] No CAPTCHA without a non-cognitive alternative (object recognition and personal content are allowed exceptions at AA, but avoid).
- [ ] At least one method avoids memory/transcription (passkey, magic link, SSO).

```tsx
// app/(auth)/sign-in/sign-in-form.tsx — identifier-first with passkey autofill (conditional mediation)
"use client";
import { useEffect, useActionState } from "react";
import { startSignIn, verifyPasskey, getPasskeyOptions } from "./actions";

export function SignInForm({ next }: { next?: string }) {
  const [state, action, pending] = useActionState(startSignIn, { email: "", error: undefined as string | undefined });

  useEffect(() => {
    const ac = new AbortController();
    (async () => {
      if (!window.PublicKeyCredential?.isConditionalMediationAvailable) return;
      if (!(await PublicKeyCredential.isConditionalMediationAvailable())) return;
      const options = await getPasskeyOptions(); // server-generated challenge (e.g., SimpleWebAuthn)
      try {
        const cred = await navigator.credentials.get({
          publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options),
          mediation: "conditional",
          signal: ac.signal,
        });
        if (cred) await verifyPasskey((cred as PublicKeyCredential).toJSON(), next);
      } catch { /* user dismissed or aborted: keep form usable */ }
    })();
    return () => ac.abort();
  }, [next]);

  return (
    <form action={action} noValidate>
      <h1 className="text-2xl font-semibold">Sign in</h1>
      <input type="hidden" name="next" value={next ?? ""} />
      <label htmlFor="email" className="mt-6 block font-medium">Email address</label>
      <input id="email" name="email" type="email" inputMode="email" autoComplete="username webauthn" defaultValue={state.email}
        aria-invalid={!!state.error} aria-describedby={state.error ? "email-error" : undefined} required />
      {state.error && <p id="email-error" className="text-sm text-red-700">{state.error}</p>}
      <button type="submit" className="btn-primary mt-4 w-full" disabled={pending}>{pending ? "Continuing..." : "Continue"}</button>
      <p className="mt-6 text-sm">New here? <a href="/sign-up" className="underline">Create an account</a></p>
    </form>
  );
}
```

Note: `parseRequestOptionsFromJSON`/`toJSON` are newer WebAuthn helpers; use `@simplewebauthn/browser` for broader support. Feature-detect `PublicKeyCredential.getClientCapabilities()` where available.

```tsx
// Password field with correct attributes and show/hide
"use client";
import { useState } from "react";
export function PasswordField({ mode }: { mode: "current" | "new" }) {
  const [show, setShow] = useState(false);
  return (
    <div>
      <label htmlFor="password" className="font-medium">Password</label>
      {mode === "new" && <p id="pw-hint" className="text-sm text-neutral-600">Use at least 15 characters. A passphrase works well.</p>}
      <div className="flex gap-2">
        <input id="password" name="password" type={show ? "text" : "password"} autoComplete={mode === "new" ? "new-password" : "current-password"}
          aria-describedby={mode === "new" ? "pw-hint" : undefined} minLength={mode === "new" ? 15 : undefined} spellCheck={false} autoCapitalize="none" />
        <button type="button" aria-pressed={show} onClick={() => setShow((s) => !s)}>{show ? "Hide" : "Show"}<span className="sr-only"> password</span></button>
      </div>
    </div>
  );
}
```

```tsx
// OTP input: single field, paste friendly
<label htmlFor="code">Enter the 6-digit code we sent to s***@example.com</label>
<input id="code" name="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} />
```

Copy bank:
- Wrong credentials: "Email or password is incorrect."
- Lockout: "Too many attempts. Try again in 15 minutes, or reset your password."
- Reset sent: "If an account exists for sam@example.com, you'll get an email with a reset link. It may take a few minutes. Check spam if you don't see it."
- Session timeout warning: "You'll be signed out in 2 minutes due to inactivity. [Stay signed in]"
- Passkey prompt: "Sign in faster next time. Create a passkey to use your fingerprint, face, or screen lock. [Create passkey] [Not now]"

## Recommended Workflow
1. Choose methods by context table; define step-up rules for sensitive actions.
2. Map flows: sign-up, sign-in, recovery, MFA enrollment, session expiry, account linking (same email via SSO + password).
3. Implement forms with correct `autocomplete`, input types, paste allowed.
4. Implement safe `next` redirect (same-origin allowlist).
5. Write copy for every error and state; avoid enumeration.
6. Test with password managers (1Password, Bitwarden, iCloud Keychain, Google Password Manager), screen readers, and mobile.
7. Monitor: sign-in success rate, reset requests, lockouts, passkey adoption.

## Patterns
- **Identifier-first** routing to SSO/passkey/password.
- **Passkey autofill** (conditional mediation) on the username field.
- **Post-login passkey upsell** once, dismissible.
- **Magic link with code fallback** (for cross-device email opening).
- **Step-up auth dialog** before sensitive changes.
- **Session-expired re-auth modal** preserving page state.
- **"Wrong door" recovery**: signing up with existing email -> "You already have an account. Sign in instead" (only after verifying email ownership to avoid enumeration).

## Anti-Patterns
- **Blocking paste / autocomplete="off"** on passwords — breaks password managers, fails 3.3.8. Fix: allow paste, correct autocomplete.
- **Composition rules and forced periodic rotation** — weaker passwords (NIST advises against). Fix: length + breach check.
- **Confirm password field** — Fix: show/hide toggle.
- **CAPTCHA on login** — accessibility and conversion killer. Fix: rate limit, risk-based checks.
- **Six separate OTP boxes that break paste** — Fix: single input or robust paste handling.
- **Open redirect via `?next=`** — Fix: validate same-origin relative paths.
- **Losing unsaved work on session expiry** — Fix: warn, extend, preserve drafts.
- **SMS-only MFA** — SIM-swap risk. Fix: passkeys/TOTP with recovery codes.

## Accessibility
- 3.3.8 Accessible Authentication (Minimum, AA); 3.3.9 (Enhanced, AAA) removes object-recognition exceptions.
- 1.3.5 Identify Input Purpose: `autocomplete` tokens.
- 2.2.1 Timing Adjustable: session timeout warnings with extension.
- 3.3.7 Redundant Entry: don't make users retype email between steps.
- Announce errors; "Show password" toggle uses `aria-pressed` and accessible name.
- Passkey browser prompts are native; ensure surrounding instructions are clear.

## Responsive Design
- Mobile: correct keyboards (`type="email"`, `inputMode="numeric"`), OTP autofill from SMS (`one-time-code`), large tap targets, avoid app-switch loss (magic link opening in another browser -> show code fallback).

## Performance
- Auth pages must be fast and lightweight; avoid heavy marketing scripts on sign-in.
- Prefetch the post-login destination.

## Security
- Rate-limit and monitor credential stuffing; breach password checks (k-anonymity API).
- Safe redirects only; CSRF protection on auth forms; secure, httpOnly, SameSite cookies.
- Don't reveal whether an email is registered in sign-in/reset messages.
- Step-up re-auth for email/password/MFA changes and destructive account actions; notify users by email on these changes.

## Testing
- Playwright: sign-in/out, wrong password, lockout, reset flow (with test inbox like Mailpit), redirect back to `next`, session expiry.
- Chrome DevTools WebAuthn virtual authenticator for passkey E2E tests.
- Manual: password managers across browsers; VoiceOver/NVDA walkthrough.

## Tooling
- Auth.js (NextAuth v5), Better Auth, Clerk, WorkOS, Auth0, Supabase Auth, Stytch; SimpleWebAuthn for passkeys; Have I Been Pwned Pwned Passwords API; FIDO Alliance passkey UX guidelines.

## Framework Notes
- **Next.js (App Router)**: auth forms as Server Actions with `useActionState`; check session in layouts/pages (not only proxy/middleware) and redirect with a validated `next`; step-up auth by checking `authTime` in the Server Action; cookies via `cookies()` in actions/route handlers.
- **React (Vite SPA)**: redirect handling in router guards; token storage per auth-token-handling skill (prefer httpOnly cookies via a backend); passkey flows identical in the browser.

## AI Agent Guidance
- Do: set correct `autocomplete` on every auth field; allow paste; implement non-enumerating copy; validate redirects; include recovery and session-expiry states.
- Don't: add password composition rules, confirm-password fields, CAPTCHAs, or `autocomplete="off"`; don't roll custom crypto.
- Verify: password manager fills fields; OTP paste works; keyboard-only flow; wrong-door and reset flows; 3.3.8 checklist passes.

## Examples
```ts
// Safe redirect helper
export function safeNext(next: string | null | undefined, fallback = "/home") {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback;
  return next;
}
```

## Related Skills
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md) — auth form components
- [nextjs-authentication](../nextjs-authentication/Skill.md) — Next.js auth implementation
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md) — token/session security
- [conversion-ux](../conversion-ux/Skill.md) — signup friction
- [onboarding-ux](../onboarding-ux/Skill.md) — what happens after signup
- [error-states](../error-states/Skill.md) — auth error messaging
- [cognitive-accessibility](../cognitive-accessibility/Skill.md) — memory and transcription burdens
- [wcag-2-2-compliance](../wcag-2-2-compliance/Skill.md) — 3.3.7, 3.3.8

## Sources
- [W3C: Understanding SC 3.3.8 Accessible Authentication (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html) — Official — requirements and exceptions
- [web.dev: Sign in with a passkey through form autofill](https://web.dev/articles/passkey-form-autofill) — Official (Google) — `username webauthn`, conditional mediation, conditional create
- [Passkey Central: Passkey accessibility / UX](https://www.passkeycentral.org/) — Official (FIDO Alliance) — passkey UX guidance
- [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) — Official — password length, no composition rules, breach checks
- [web.dev: Sign-in form best practices](https://web.dev/articles/sign-in-form-best-practices) — Official (Google) — autocomplete, show password
- [Auth0: Accessible guide to WCAG 3.3.8](https://auth0.com/blog/an-accessible-guide-to-wcag-3-3-8-authentication-without-frustration/) — Community (vendor) — practical alternatives
- [SimpleWebAuthn](https://simplewebauthn.dev/) — Open Source (MIT)

## License / Usage Notes
W3C/NIST content public; summarized. Code original; SimpleWebAuthn MIT.

## Quality Tier
S — standards-backed (W3C, NIST, FIDO) with verified current browser APIs.

## Status
Active

## Last Verified
2026-09-15
