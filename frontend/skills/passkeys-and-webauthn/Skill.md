# Passkeys and WebAuthn

## Summary
Add phishing-resistant passkey sign-in to Next.js and React apps using the Web Authentication API. This skill covers the registration and authentication flows (WebAuthn calls them "ceremonies"), autofill-based passkey sign-in (conditional UI), and server-side verification with SimpleWebAuthn or a managed provider such as Better Auth or Clerk (Auth.js support is experimental). It also covers the security details teams get wrong most often: storing challenges, checking origin and RP ID, user verification, and account recovery.

## Category
Security

## Subcategories
WebAuthn, FIDO2, passkeys, conditional mediation, discoverable credentials, related origin requests, Signal API, account recovery, SimpleWebAuthn, Better Auth, Clerk, Auth.js

## Problem It Solves
Passwords and SMS codes can be phished, reused, and stuffed. Passkeys are key pairs bound to your domain: the private key never leaves the authenticator, and the signature only verifies for your RP ID. That eliminates credential phishing. Adoption still fails when the UX is poor (a modal the user didn't ask for, no fallback, no way to manage passkeys) or when server verification is loose (reused challenges, unchecked origin). This skill gives a correct, production-ready pattern.

## When To Use
- Adding passwordless or "sign in with passkey" to an app that already has accounts.
- Replacing SMS/TOTP second factors with a phishing-resistant factor.
- Building a passkey management page (list, rename, delete) in account settings.
- Running one account across related domains (country TLDs, rebrands).

## When Not To Use
- Your identity provider (Clerk, Auth0, Entra, Cognito, Better Auth) already provides passkeys. Use its SDK rather than hand-rolling WebAuthn.
- Non-HTTPS environments other than `localhost`. WebAuthn requires a secure context.
- Plain OTP or magic-link flows. See [otp-and-auth-forms](../otp-and-auth-forms/Skill.md).
- Deciding session and token storage. See [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md).

## Core Principles
1. **Challenges are server-generated, random, single-use, short-lived, and bound to the session.** Never generate them in the browser.
2. **Verify everything on the server:** challenge, exact origin, RP ID hash, signature, user-presence flag, and user-verification flag when the passkey replaces MFA.
3. **Passkeys supplement other sign-in methods before they replace them.** Always provide a graceful fallback and a recovery path.
4. **Use conditional UI (autofill) for sign-in.** Put `autocomplete="username webauthn"` on the username field so passkeys show up in autofill without an unexpected modal.
5. **The user handle (`user.id`) is random, stable bytes, never an email or username.** It is stored on the authenticator and must not contain PII.
6. **Pick the RP ID once.** Passkeys are bound to it (for example `example.com`, which also covers subdomains). Changing it later orphans every existing passkey.

## Best Practices
- Registration options: `residentKey: 'required'` (discoverable), `userVerification: 'preferred'`, `attestationType: 'none'`, and `excludeCredentials` set to the user's existing passkeys.
- Don't force `authenticatorAttachment: 'platform'` unless you have a reason. Leaving it unset lets users pick a phone or security key.
- Offer passkey creation at high-intent moments: after a password or OTP sign-in, after a cross-device sign-in (`authenticatorAttachment === 'cross-platform'`: "Use this device next time?"), during signup, and from settings.
- Name each stored passkey from its AAGUID (for example "Google Password Manager" or "iCloud Keychain") and record created and last-used timestamps.
- Don't ask for a second factor after a passkey sign-in with user verification. It's already multi-factor.
- After a successful sign-in, call `PublicKeyCredential.signalAllAcceptedCredentials()`. When the server doesn't recognise a credential ID, call `signalUnknownCredential()`. Both keep password managers in sync. Feature-detect both.
- Send an email or notification whenever a passkey is added or removed.
- Require recent re-authentication (step-up) before adding or deleting passkeys.
- Use the word "passkey" consistently (lowercase in running text), and give passkeys a clear section in account settings (FIDO Alliance required patterns).

## Implementation Guidance

**Choose an approach**

| Situation | Choice | Notes |
|---|---|---|
| Using Clerk | Enable passkeys in the dashboard; `user.createPasskey()`, `signIn.authenticateWithPasskey()` | Bound to the domain; doesn't work across satellite domains |
| Using Better Auth | `@better-auth/passkey` plugin plus `passkeyClient()` | `signIn.passkey({ autoFill: true })` for conditional UI; needs a `passkey` table |
| Using Auth.js (next-auth v5 beta) | Passkey provider with `experimental.enableWebAuthn` | Docs mark it experimental and not recommended for production; pins an old SimpleWebAuthn |
| Custom auth / existing session system | SimpleWebAuthn v14 (`@simplewebauthn/server` + `/browser`) | Node 22+; you own challenge storage and DB schema |

**Data model (custom)**
- `users.webauthnUserId`: random 32-64 bytes (base64url), generated once per user.
- `passkeys`: `id` (credential ID, base64url, unique, indexed), `userId` FK, `publicKey` (bytes), `counter` (int), `transports` (string[]), `deviceType` (`singleDevice`/`multiDevice`), `backedUp` (bool), `aaguid`, `name`, `createdAt`, `lastUsedAt`.
- `webauthn_challenges` (or a server-side session field): `challenge`, `purpose` (`reg`/`auth`), `sessionId`, `expiresAt` (about 5 minutes). Delete the row when it's used.

**Server flow (Next.js)**
1. `getRegistrationOptions()` (Server Action or Route Handler) runs `requireSession()`, then `generateRegistrationOptions`, stores the challenge, and returns the JSON options.
2. The client calls `startRegistration({ optionsJSON })` and sends the result to `verifyRegistration(response)`.
3. `verifyRegistration` loads and deletes the challenge, runs `verifyRegistrationResponse` with the expected challenge, origin, and RP ID, then stores `registrationInfo.credential`.
4. Sign-in: `getAuthenticationOptions()` (with empty `allowCredentials` for discoverable credentials) stores a challenge tied to an anonymous pre-auth cookie. The client runs `startAuthentication({ optionsJSON, useBrowserAutofill: true })`. The server looks up the credential by `response.id`, runs `verifyAuthenticationResponse`, updates the counter and `lastUsedAt`, and creates the session.

**Related origins.** For `example.co.uk` to use passkeys from RP ID `example.com`, serve JSON `{ "origins": ["https://example.co.uk"] }` at `https://example.com/.well-known/webauthn`. The limit is 5 unique labels. Detect support with `getClientCapabilities()` (`relatedOrigins`), and fall back to per-domain passkeys or redirecting to the primary domain.

## Recommended Workflow
1. Fix the RP ID, the allowed origins (including preview and staging hosts), and the RP name. Put them in server-only env config.
2. Add the schema: user handle, passkeys table, challenge storage.
3. Build registration from settings first. Verify it with Chrome DevTools' WebAuthn panel (virtual authenticator).
4. Add the conditional UI sign-in on the existing login form, plus a "Sign in with a passkey" button that uses modal mediation for browsers without autofill.
5. Add the post-sign-in upgrade prompt and the cross-device "use this device next time" prompt.
6. Add management (list, rename, delete with step-up), notifications, and the Signal API calls.
7. Define recovery: allow multiple passkeys, verified email or recovery codes that lead to re-enrollment, and a support path.
8. Test on real iOS, Android, macOS, and Windows with synced and hardware authenticators. Then add e2e tests with a virtual authenticator.

## Patterns
- **Autofill-first login:** username input `autoComplete="username webauthn"`. On mount, start a conditional `startAuthentication` and abort it on unmount. The password path keeps working the whole time.
- **Explicit passkey button:** modal mediation for users who prefer it or browsers without conditional UI.
- **Upgrade interstitial:** after a password or OTP sign-in, if `isUserVerifyingPlatformAuthenticatorAvailable()` is true, offer "Create a passkey". The user can dismiss it; remember the dismissal.
- **Challenge-in-DB with TTL:** a single-use row keyed to the session. Atomic delete-on-read prevents replay.
- **Well-known route:** `app/.well-known/webauthn/route.ts` returns the origins JSON.

## Anti-Patterns
- **Storing the challenge in a readable client cookie or localStorage and trusting it.** An attacker who controls the client controls the challenge. Fix: keep it server-side, or at minimum in a signed/encrypted httpOnly cookie that is single-use (track a nonce) and expires.
- **Reusing challenges, or never expiring them.** This allows replay. Fix: delete the challenge on verification and add a TTL.
- **`expectedOrigin` built from the request `Host`/`Origin` header.** That trusts attacker-controlled input. Fix: use a static allowlist from server config.
- **Using email as `user.id`.** It leaks PII onto authenticators and breaks when the email changes. Fix: random bytes.
- **Opening a modal WebAuthn prompt on page load.** It's confusing and users dismiss it. Fix: conditional mediation.
- **Passkeys as the only method with no recovery.** Users get locked out when they lose a device. Fix: allow multiple passkeys, verified recovery, and step-up re-enrollment.
- **Rejecting a counter of 0.** Synced passkeys often always report 0. Fix: only flag a decrease when the counter is non-zero.
- **Forcing `userVerification: 'required'` everywhere.** Devices without biometrics fail. Fix: use `preferred`, and check `userVerified` server-side when policy requires it.
- **Not aborting the conditional request.** Starting a modal ceremony, or re-mounting under React Strict Mode, throws an abort error or leaves a stale request. Fix: abort in effect cleanup and ignore `ERROR_CEREMONY_ABORTED`.

## Accessibility
- Passkey prompts are OS/browser UI, but your surrounding UI must meet WCAG: label the "Sign in with a passkey" button, announce failures in a live region, and don't auto-redirect before errors can be read.
- Keep the username field a real labelled input. Conditional UI depends on it, and so do screen-reader users.
- WCAG 2.2 SC 3.3.8 Accessible Authentication (Minimum): passkeys are a good way to meet it because they need no memorisation or transcription. Never block paste in fallback fields.
- If the user cancels, return focus to the triggering control and show a non-blocking explanation. See [accessible-forms](../accessible-forms/Skill.md).

## Responsive Design
- On mobile, the OS sheet covers part of the page. Keep the form visible and don't rely on layout behind it.
- On desktop without a platform authenticator, the browser offers QR-based cross-device (hybrid) sign-in. Copy should say "use your phone" rather than implying a fingerprint is required.

## Performance
- Load `@simplewebauthn/browser` only on auth and settings routes. It's small, but keep it out of the global bundle.
- Generating options is a cheap server call. Don't prefetch challenges on every page, because they expire and clutter storage.

## Security
- Verify the RP ID hash, exact origin (allowlist), challenge, signature, UP flag, and UV flag (when the passkey counts as MFA). SimpleWebAuthn checks these when you pass the expected values.
- Rate-limit options generation and verification per IP and account. Log verification failures.
- Keep RP config, DB access, and verification in `server-only` modules. Never expose them in `NEXT_PUBLIC_*`.
- Sign-in with a passkey must create the same hardened session as any other method (httpOnly, Secure, SameSite cookie; rotate on login). See [nextjs-authentication](../nextjs-authentication/Skill.md).
- Adding or removing passkeys requires recent authentication, plus notification.
- Account recovery is the weakest link. Treat email-based recovery as a lower assurance level: require re-verification and consider a delay or notification before new passkeys are trusted for sensitive actions.
- CSP: WebAuthn needs no special CSP directives. Keep a strict CSP on auth pages. See [content-security-policy](../content-security-policy/Skill.md).
- Attestation `none` is right for consumer apps. Only enterprise and regulated flows should require attestation and AAGUID allowlists.

## Testing
- **Unit:** mock `@simplewebauthn/server` verification and test challenge expiry, single use, origin allowlist, counter logic, and step-up enforcement.
- **E2E (Playwright, Chromium):** create a CDP session, `WebAuthn.enable`, then `WebAuthn.addVirtualAuthenticator` with `{ protocol: 'ctap2', transport: 'internal', hasResidentKey: true, hasUserVerification: true, isUserVerified: true }`. Run register, sign out, and sign in.
- **Manual:** Chrome DevTools > More tools > WebAuthn. Real devices: iPhone (iCloud Keychain), Android (Google Password Manager), Windows Hello, a hardware security key, and cross-device QR sign-in.
- Test cancel and timeout paths, an already-registered device (`InvalidStateError`), and deleted-credential sign-in (triggers `signalUnknownCredential`).

## Tooling
- `@simplewebauthn/server` and `@simplewebauthn/browser` v14.x (Active; Node 22+, Deno 2.4+).
- Better Auth `@better-auth/passkey` (Active).
- Clerk passkeys (Active, managed; domain-bound).
- Auth.js Passkey provider (Experimental; docs pin SimpleWebAuthn 9.x; Check current docs).
- passkeys.dev (reference docs; AAGUID lists linked from there), Chrome DevTools WebAuthn panel.

## Framework Notes
- **Next.js (App Router):** Use Server Actions or Route Handlers for options and verification. Both accept and return plain JSON (`PublicKeyCredentialCreationOptionsJSON`, `RegistrationResponseJSON`). Mark modules `import 'server-only'`. Use `cookies()` for the pre-auth session ID. The ceremony itself must run in a `'use client'` component. Serve `/.well-known/webauthn` from a Route Handler. Proxy/middleware must not rewrite or block `/.well-known/*`. Preview deployments get different origins, so either allowlist them or turn passkeys off in previews. See [nextjs-server-actions](../nextjs-server-actions/Skill.md) and [nextjs-route-handlers](../nextjs-route-handlers/Skill.md).
- **React (Vite SPA):** Same client code, but the server is your API (Express, Hono, and so on). Send options and responses as JSON over `fetch` with credentials. If the API is on a different origin, the RP ID must still be a registrable suffix of the page origin, and `expectedOrigin` is the SPA's origin, not the API's.

## AI Agent Guidance
- DO check first whether the project's auth provider already supports passkeys, and use its SDK if so.
- DO generate and store challenges server-side, verify with a static origin/RP ID allowlist, and delete challenges when used.
- DO add `autoComplete="username webauthn"` and an abortable conditional request. Keep password or OTP fallback working.
- DO use random bytes for the user handle, `residentKey: 'required'`, `userVerification: 'preferred'`, and `attestationType: 'none'`.
- DON'T put secrets or RP config in client env vars, derive origin from request headers, or remove existing sign-in methods.
- DON'T invent SimpleWebAuthn option names. Check the installed major version's docs, because the API changed between v9 and v13+ (for example `optionsJSON` and `registrationInfo.credential`).
- Before declaring done: register and sign in with a virtual authenticator in e2e tests, confirm a reused challenge is rejected, confirm a wrong origin is rejected, confirm the cancel path returns focus and shows a message, and confirm recovery and management UI exist or are tracked as follow-ups.

## Examples

```ts
// lib/webauthn/config.ts
import 'server-only';
export const rpID = process.env.WEBAUTHN_RP_ID!;          // e.g. "example.com" or "localhost"
export const rpName = 'Acme';
export const expectedOrigins = (process.env.WEBAUTHN_ORIGINS ?? '').split(','); // e.g. "https://example.com"
```

```ts
// app/(auth)/passkeys/actions.ts
'use server';
import {
  generateRegistrationOptions, verifyRegistrationResponse,
  generateAuthenticationOptions, verifyAuthenticationResponse,
  type RegistrationResponseJSON, type AuthenticationResponseJSON,
} from '@simplewebauthn/server';
import { isoBase64URL } from '@simplewebauthn/server/helpers';
import { rpID, rpName, expectedOrigins } from '@/lib/webauthn/config';
import { db } from '@/lib/db';
import { requireRecentSession, getPreAuthId, createSession } from '@/lib/session';

export async function getRegistrationOptions() {
  const { user, sessionId } = await requireRecentSession(); // step-up enforced
  const existing = await db.passkey.findMany({ where: { userId: user.id } });
  const options = await generateRegistrationOptions({
    rpName, rpID,
    userName: user.email,
    userID: isoBase64URL.toBuffer(user.webauthnUserId), // random bytes, not the email
    attestationType: 'none',
    excludeCredentials: existing.map((p) => ({ id: p.id, transports: p.transports })),
    authenticatorSelection: { residentKey: 'required', userVerification: 'preferred' },
  });
  await db.challenge.create({
    data: { sessionId, purpose: 'reg', challenge: options.challenge, expiresAt: new Date(Date.now() + 5 * 60_000) },
  });
  return options;
}

export async function verifyRegistration(response: RegistrationResponseJSON) {
  const { user, sessionId } = await requireRecentSession();
  const row = await db.challenge.consume({ sessionId, purpose: 'reg' }); // atomic delete + expiry check
  if (!row) return { ok: false as const, error: 'Challenge expired. Please try again.' };

  const { verified, registrationInfo } = await verifyRegistrationResponse({
    response, expectedChallenge: row.challenge, expectedOrigin: expectedOrigins, expectedRPID: rpID,
  });
  if (!verified || !registrationInfo) return { ok: false as const, error: 'Could not verify passkey.' };

  const { credential, credentialDeviceType, credentialBackedUp, aaguid } = registrationInfo;
  await db.passkey.create({
    data: {
      id: credential.id, userId: user.id, publicKey: Buffer.from(credential.publicKey),
      counter: credential.counter, transports: credential.transports ?? [],
      deviceType: credentialDeviceType, backedUp: credentialBackedUp, aaguid,
    },
  });
  // notify user out-of-band that a passkey was added
  return { ok: true as const };
}

export async function getAuthenticationOptions() {
  const preAuthId = await getPreAuthId(); // httpOnly cookie, set if missing
  const options = await generateAuthenticationOptions({ rpID, userVerification: 'preferred' }); // empty allowCredentials = discoverable
  await db.challenge.create({
    data: { sessionId: preAuthId, purpose: 'auth', challenge: options.challenge, expiresAt: new Date(Date.now() + 5 * 60_000) },
  });
  return options;
}

export async function verifyAuthentication(response: AuthenticationResponseJSON) {
  const preAuthId = await getPreAuthId();
  const row = await db.challenge.consume({ sessionId: preAuthId, purpose: 'auth' });
  const passkey = await db.passkey.findUnique({ where: { id: response.id } });
  if (!row || !passkey) return { ok: false as const, unknownCredentialId: passkey ? undefined : response.id };

  const { verified, authenticationInfo } = await verifyAuthenticationResponse({
    response, expectedChallenge: row.challenge, expectedOrigin: expectedOrigins, expectedRPID: rpID,
    credential: { id: passkey.id, publicKey: new Uint8Array(passkey.publicKey), counter: passkey.counter, transports: passkey.transports },
  });
  if (!verified) return { ok: false as const };

  await db.passkey.update({ where: { id: passkey.id }, data: { counter: authenticationInfo.newCounter, lastUsedAt: new Date() } });
  await createSession(passkey.userId); // rotates session cookie
  return { ok: true as const };
}
```

```tsx
// app/(auth)/login/PasskeyLogin.tsx
'use client';
import { useEffect, useState } from 'react';
import { startAuthentication, browserSupportsWebAuthnAutofill, WebAuthnError } from '@simplewebauthn/browser';
import { getAuthenticationOptions, verifyAuthentication } from '../passkeys/actions';

async function signInWithPasskey(autofill: boolean) {
  const optionsJSON = await getAuthenticationOptions();
  const response = await startAuthentication({ optionsJSON, useBrowserAutofill: autofill });
  return verifyAuthentication(response);
}

export function PasskeyLogin() {
  const [error, setError] = useState('');

  const handle = async (autofill: boolean) => {
    try {
      const result = await signInWithPasskey(autofill);
      if (result.ok) return window.location.assign('/dashboard');
      if ('unknownCredentialId' in result && result.unknownCredentialId && 'signalUnknownCredential' in PublicKeyCredential) {
        // @ts-expect-error: Signal API not yet in all TS DOM libs
        await PublicKeyCredential.signalUnknownCredential({ rpId: location.hostname, credentialId: result.unknownCredentialId });
      }
      setError('That passkey could not be used. Try another method.');
    } catch (e) {
      if (e instanceof WebAuthnError && e.code === 'ERROR_CEREMONY_ABORTED') return; // unmount or modal started
      if (e instanceof Error && e.name === 'NotAllowedError') return; // user cancelled; fallback stays available
      setError('Passkey sign-in failed. Try again or use your password.');
    }
  };

  useEffect(() => {
    browserSupportsWebAuthnAutofill().then((ok) => ok && handle(true));
    // startAuthentication cancels any previous ceremony when a new one starts
  }, []);

  return (
    <form action="/login/password" method="post">
      <label htmlFor="username">Email</label>
      <input id="username" name="username" type="email" autoComplete="username webauthn" required />
      <label htmlFor="password">Password</label>
      <input id="password" name="password" type="password" autoComplete="current-password" />
      <button type="submit">Continue</button>
      <button type="button" onClick={() => handle(false)}>Sign in with a passkey</button>
      <p role="status" aria-live="polite">{error}</p>
    </form>
  );
}
```

```ts
// app/.well-known/webauthn/route.ts — Related Origin Requests (served on the RP ID domain)
export const dynamic = 'force-static';
export function GET() {
  return Response.json({ origins: ['https://example.co.uk', 'https://example.de'] });
}
```

## Related Skills
- [authentication-ux](../authentication-ux/Skill.md): sign-in and sign-up flow design, fallback messaging
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md): OTP/password fallback fields and autocomplete tokens
- [nextjs-authentication](../nextjs-authentication/Skill.md): sessions, providers, route protection
- [frontend-auth-token-handling](../frontend-auth-token-handling/Skill.md): session cookie handling after passkey sign-in
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): securing the option and verify actions
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md): the well-known file and API-style endpoints
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md): threat model context
- [content-security-policy](../content-security-policy/Skill.md): hardening auth pages
- [accessible-forms](../accessible-forms/Skill.md): labelled inputs and error announcements
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md): virtual authenticator e2e tests

## Sources
- [MDN: Web Authentication API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API): Official. Ceremonies, JSON helpers, `getClientCapabilities`, Signal API methods, secure context, RP ID rules.
- [web.dev: Sign in with a passkey through form autofill](https://web.dev/articles/passkey-form-autofill): Official (Google). Conditional mediation, AbortController, post-sign-in upgrade, Signal API.
- [web.dev: Create a passkey for passwordless logins](https://web.dev/articles/passkey-registration): Official (Google). Registration options, random user ID, storage fields, where to offer creation.
- [passkeys.dev: Related Origin Requests](https://passkeys.dev/docs/advanced/related-origins/): Official (W3C/FIDO community). Well-known file format, 5-label limit, capability detection.
- [passkeys.dev: Bootstrapping](https://passkeys.dev/docs/use-cases/bootstrapping/): Official. Conditional UI flow, fallback, cross-device enrollment prompt, UV preferred.
- [SimpleWebAuthn server docs](https://simplewebauthn.dev/docs/packages/server): Open Source. v14 API, return shapes, DB fields.
- [SimpleWebAuthn browser docs](https://simplewebauthn.dev/docs/packages/browser): Open Source. `startRegistration`/`startAuthentication`, autofill, `WebAuthnError` codes.
- [Better Auth passkey plugin](https://www.better-auth.com/docs/plugins/passkey): Open Source. Package, config, autofill.
- [Auth.js WebAuthn](https://authjs.dev/getting-started/authentication/webauthn): Open Source. Experimental status and requirements.
- [Clerk passkeys custom flow](https://clerk.com/docs/guides/development/custom-flows/authentication/passkeys): Vendor. APIs and domain restrictions.
- [Passkey Central design guidelines](https://www.passkeycentral.org/design-guidelines/required-patterns/): Official (FIDO Alliance). Required patterns (creation and management, sign-in with fallback).

## License / Usage Notes
SimpleWebAuthn is MIT. Better Auth is MIT. Auth.js is ISC. Clerk is commercial. MDN content is CC-BY-SA, and web.dev text is CC-BY 4.0. All content here is summarized, not copied, and the code is original. The `db.challenge.consume` and session helpers are placeholders for your own implementation. Details of the FIDO pattern pages (wording, icon) were not fetched: Check current docs.

## Quality Tier
A: built from MDN, web.dev, passkeys.dev, and current library docs (SimpleWebAuthn v14). Detailed FIDO UX pattern pages and the exact Signal API TypeScript typings weren't verified.

## Status
Active

## Last Verified
2026-09-15
