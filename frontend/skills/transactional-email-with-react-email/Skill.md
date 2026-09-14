# Transactional Email with React Email

## Summary
React Email lets you build transactional emails (welcome, verification, password reset, receipts, invites, dunning) as typed React components. They render to email-client-safe HTML and plain text. As of v6 (April 2026) components and render utilities come from a single `react-email` package, and the preview UI lives in `@react-email/ui`. This skill covers authoring, rendering, sending from Next.js 16.3.x Server Actions and Route Handlers via Resend (or SES, Postmark, Nodemailer), previewing, dark mode and client quirks, accessibility, and deliverability basics.

## Category
Product Patterns

## Subcategories
Email, Server Actions, Notifications, Deliverability, Templates, Accessibility

## Problem It Solves
Hand-written email HTML is fragile (table layouts, inline styles, Outlook quirks), untyped, and hard to preview. Sends get scattered through the codebase with no retries, no idempotency, and no plain-text fallback, and domains get flagged as spam. React Email plus a disciplined send layer makes templates maintainable and sends reliable.

## When To Use
- Any product email triggered by a user action or system event: auth, billing, invites, alerts.
- Teams already on React/TypeScript who want templates in the repo, reviewed like code.
- Receipts or notifications driven by Stripe webhooks or background jobs.

## When Not To Use
- Marketing newsletters and campaigns managed by non-developers. Use an ESP's campaign editor and audience tools (you can still export React Email HTML).
- Very high-volume bulk sends without a queue and suppression management. Build that infrastructure first.
- In-app notifications or push. Different channel.

## Core Principles
1. Emails are rendered on the server only. Templates never import client-only code or secrets.
2. Every email ships HTML plus a plain-text part and a meaningful preview (preheader) line.
3. Design for the weakest client: table-based layout (React Email handles it), inline styles, px units, and no reliance on JS, web fonts, or hover.
4. Sends are side effects that can fail or duplicate. Use idempotency keys, check errors, and use queues for critical or bulk sends.
5. Authenticate your sending domain (SPF, DKIM, DMARC) and send from a dedicated subdomain.
6. Never put secrets or long-lived tokens in emails beyond single-use, expiring links.

## Best Practices
- Put templates in `emails/` (or `src/emails/`) as default exports with typed props and `PreviewProps` for the preview server.
- Use `<Preview>` for inbox preheader text, `<Html lang="en">`, and `<Head>` with `color-scheme` meta.
- Style with `<Tailwind config={{ presets: [pixelBasedPreset] }}>` so rem converts to px. Avoid `space-*`, `prose`, and hover utilities (not inlined or unsupported).
- Keep width at 600px or less with a `Container`, body text 14-16px, and tap targets 44px or larger.
- Buttons use absolute HTTPS URLs. Link text describes the destination ("Reset your password", not "Click here").
- Generate plain text with `render(<Email />, { plainText: true })` or `toPlainText(html)`. Mark decorative blocks `data-skip-in-text="true"`.
- Keep total HTML under about 100KB. Gmail clips larger messages (community-documented threshold, check current).
- Resend: env `RESEND_API_KEY`, check `{ data, error }` (the SDK doesn't throw on API errors), and pass an idempotency key for retried sends (24h window).
- Choose inline vs deferred per email: password reset and verification go inline or through a durable queue. "Thanks for your feedback" can go in `after()`.
- Separate transactional and marketing streams (different subdomains, and different providers or streams).
- Handle bounces and complaints through provider webhooks. Verify their signatures and suppress bad addresses.

## Implementation Guidance
**Setup (v6)**
1. `npm i react-email` and `npm i -D @react-email/ui`. Add the script `"email:dev": "email dev"` (check current docs for the `--dir` flag if templates aren't in `emails/`).
2. Import components from `react-email`: `Html, Head, Body, Container, Section, Row, Column, Heading, Text, Button, Link, Img, Hr, Preview, Tailwind, CodeBlock, CodeInline, Markdown, Font`.
3. Render with `await render(element)` (async) or pass `react: <Email />` to Resend.
4. Upgrading from `@react-email/components` or the individual `@react-email/*` packages: switch imports to `react-email` per the official "Updating React Email" guide.

**Provider decision**

| Need | Option |
|---|---|
| Simple DX, React-native API, Next.js on Vercel | Resend (`resend.emails.send({ react })`) |
| AWS-centric, cost at scale | Amazon SES + `render()` HTML |
| Strong transactional deliverability tooling | Postmark (message streams) |
| SMTP / self-hosted relay | Nodemailer + `render()` |

Prefer HTTP APIs over SMTP on serverless (connection limits and cold starts).

**Where to send from**

| Trigger | Location |
|---|---|
| User form (invite, contact) | Server Action (validate, auth, rate limit) |
| Auth flows | Auth library callback, inline |
| Stripe events (receipt, dunning) | Webhook handler, enqueued job |
| Digest/scheduled | Cron or queue worker |

## Recommended Workflow
1. List the emails, their triggers, criticality (inline or queue), and required data.
2. Build a shared `EmailLayout` (logo, container, footer with company address and support link).
3. Author each template with `PreviewProps`, and iterate in the preview server with the dark-mode toggle and client emulation.
4. Build a `sendEmail` wrapper (server-only) that renders the text part, sets tags and headers, handles `error`, and supports idempotency.
5. Wire triggers (Server Actions, webhooks, jobs) and add rate limits on user-triggered sends.
6. Verify the domain (SPF, DKIM, DMARC) on a subdomain and set up bounce and complaint webhooks.
7. Test in real clients (Gmail web and app, Apple Mail, Outlook desktop and web) before launch.

## Patterns
**Template with layout, preview text, Tailwind**
```tsx
// emails/reset-password.tsx
import { Html, Head, Body, Container, Heading, Text, Button, Preview, Hr, Tailwind, pixelBasedPreset } from 'react-email'

type Props = { name: string; resetUrl: string; expiresInMinutes: number }

export default function ResetPasswordEmail({ name, resetUrl, expiresInMinutes }: Props) {
  return (
    <Html lang="en">
      <Head>
        <meta name="color-scheme" content="light dark" />
        <meta name="supported-color-schemes" content="light dark" />
      </Head>
      <Preview>Reset your Acme password (link expires in {String(expiresInMinutes)} minutes)</Preview>
      <Tailwind config={{ presets: [pixelBasedPreset] }}>
        <Body className="bg-white font-sans text-gray-900">
          <Container className="mx-auto max-w-[600px] p-6">
            <Heading as="h1" className="text-2xl">Reset your password</Heading>
            <Text className="text-base">Hi {name}, we received a request to reset your password.</Text>
            <Button href={resetUrl} className="rounded-md bg-blue-700 px-5 py-3 text-base font-semibold text-white">
              Reset your password
            </Button>
            <Text className="text-sm text-gray-600">
              This link expires in {expiresInMinutes} minutes. If you didn't request this, you can ignore this email.
            </Text>
            <Hr />
            <Text className="text-xs text-gray-500" data-skip-in-text="true">Acme Inc., 123 Example St, City</Text>
          </Container>
        </Body>
      </Tailwind>
    </Html>
  )
}

ResetPasswordEmail.PreviewProps = {
  name: 'Ada', resetUrl: 'https://example.com/reset?token=preview', expiresInMinutes: 30,
} satisfies Props
```

**Server-only send wrapper (Resend)**
```ts
// lib/email.ts
import 'server-only'
import type { ReactElement } from 'react'
import { Resend } from 'resend'
import { render } from 'react-email'

const resend = new Resend(process.env.RESEND_API_KEY)
const FROM = process.env.EMAIL_FROM! // e.g. "Acme <no-reply@mail.example.com>"

export async function sendEmail(opts: {
  to: string; subject: string; template: ReactElement; idempotencyKey?: string; tags?: { name: string; value: string }[]
}) {
  const text = await render(opts.template, { plainText: true })
  const { data, error } = await resend.emails.send(
    { from: FROM, to: [opts.to], subject: opts.subject, react: opts.template, text, tags: opts.tags },
    opts.idempotencyKey ? { idempotencyKey: opts.idempotencyKey } : undefined,
  )
  if (error) throw new Error(`Email send failed: ${error.name}`) // don't log recipient PII or tokens
  return data!.id
}
```
Where `idempotencyKey` goes (second options argument vs payload) depends on SDK version, so check current Resend docs.

**Server Action: send an invite (validated, authorized, rate limited)**
```ts
// app/team/actions.ts
'use server'
import { z } from 'zod'
import { requireUser } from '@/lib/auth'
import { rateLimit } from '@/lib/rate-limit'
import { sendEmail } from '@/lib/email'
import InviteEmail from '@/emails/invite'

const schema = z.object({ email: z.email(), teamId: z.string().min(1) })

export async function inviteMember(_: unknown, formData: FormData) {
  const user = await requireUser()
  const parsed = schema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { error: 'Enter a valid email address.' }
  await assertCanInvite(user.id, parsed.data.teamId)
  if (!(await rateLimit(`invite:${user.id}`, { limit: 20, windowSec: 3600 }))) return { error: 'Too many invites. Try later.' }

  const invite = await createInvite(parsed.data) // single-use token, expires
  await sendEmail({
    to: parsed.data.email,
    subject: `${user.name} invited you to ${invite.teamName}`,
    template: <InviteEmail inviter={user.name} team={invite.teamName} acceptUrl={invite.url} />,
    idempotencyKey: `invite:${invite.id}`,
  })
  return { ok: true }
}
```
This file uses JSX, so name it `actions.tsx`, or build the element in a `.tsx` helper. zod v4 uses `z.email()`, while v3 uses `z.string().email()`.

## Anti-Patterns
- **Rendering templates in Client Components or leaking the provider key via `NEXT_PUBLIC_RESEND_API_KEY`.** Anyone can send as your domain. Fix: server-only module and env.
- **HTML-only emails.** Worse deliverability and accessibility. Fix: always include a plain-text part.
- **Relying on `<style>` media queries, hover, or web fonts for essential content.** Gmail and Outlook strip or ignore them. Fix: inline styles, system font stack, progressive enhancement only.
- **Pure `#000` on `#fff` with dark logos on transparent backgrounds.** Clients that auto-invert make logos disappear. Fix: off-black and off-white colors, and logos with a light outline or a solid background tile.
- **Ignoring `{ error }` from Resend.** Failures are silent. Fix: check the result and throw or log with a correlation ID.
- **Sending password-reset emails in `after()` with no retry.** Users get locked out when the send drops. Fix: send inline, or use a durable queue with retries.
- **Unauthenticated, unthrottled contact or invite endpoints.** Spam relay and reputation damage. Fix: auth, rate limits, CAPTCHA for public forms.
- **Putting user-controlled strings into `subject` or `from` unvalidated.** Header manipulation and phishing-looking mail. Fix: validate, cap length, strip newlines, and keep `from` fixed server-side.
- **Long-lived or reusable tokens in links.** A forwarded email means a compromised account. Fix: single-use, short-expiry, hashed-at-rest tokens.
- **Sending from the root domain for everything.** One bad campaign hurts all mail. Fix: dedicated subdomains per stream.

## Accessibility
- `<Html lang>` set, with a logical heading order (`h1` then `h2`), mapping to WCAG 1.3.1 and 3.1.1.
- Every image has `alt`, decorative images `alt=""`, and key content is never image-only (1.1.1).
- Contrast of at least 4.5:1 for body text, including in dark-mode-inverted clients (1.4.3).
- Descriptive link and button text (2.4.4). Buttons are real links with large tap targets.
- Layout tables must not be announced as data tables. React Email layout components render presentational tables (check with a screen reader).
- A plain-text version fully conveys the message and actions.
- Left-align body text, keep line length short, and avoid all-caps paragraphs.

## Responsive Design
- Single-column layout under a 600px container works everywhere. Multi-column `Row`/`Column` should stack gracefully or stay simple.
- Fluid images (`width="100%"` with a max width) and explicit `width`/`height` attributes to avoid layout jumps.
- Media queries render in supporting clients but aren't inlined, so the default (no-media-query) layout must already work on mobile.
- Minimum 14px text on mobile, and buttons full-width or 44px+ tall.

## Performance
- Render at send time on the server. Rendering is cheap, but don't render inside hot request paths when a queue can do it.
- Host images on a CDN with absolute URLs, compress them, and avoid heavy GIFs. Keep total HTML under about 100KB.
- Batch or queue bulk sends and respect provider rate limits with backoff.
- Reuse a single provider client per module (avoid creating new SMTP connections per send on serverless).

## Security
- Provider API keys are server-only, least-privilege (send-only keys where offered), and rotated.
- Auth links: single-use, expiring (15-60 min for reset), tokens hashed in the DB, and the link domain matches your app domain.
- Don't include sensitive data (full card numbers, passwords, secrets) in email bodies. Emails are stored and forwarded.
- React escapes interpolated strings by default. Never pass user content into `dangerouslySetInnerHTML` or the `<Markdown>` component without sanitizing.
- Verify webhook signatures from your provider (bounces, complaints, inbound) before acting. Check current docs for the provider's scheme.
- Log message IDs, not recipient addresses or link tokens.
- SPF, DKIM, and DMARC (start `p=none` with reporting, move toward `quarantine`/`reject`) prevent spoofing of your domain.

## Testing
- **Unit and snapshot (Vitest):** `const html = await render(<ResetPasswordEmail {...props} />)`. Assert that the reset URL and expiry text are present, `lang` is set, and the plain-text output contains the URL.
- **Preview server:** check each template's `PreviewProps`, the dark-mode switcher (emulates client color inversion), and mobile width.
- **Integration:** send to provider test addresses (Resend `delivered@resend.dev`; bounce and complaint test addresses exist, check current docs) and check that `data.id` is returned.
- **Real-client checks** in Gmail, Apple Mail, and Outlook, or an Email on Acid or Litmus style service, before launch and after major layout changes.
- **Deliverability:** check SPF, DKIM, and DMARC alignment in received headers, and run a spam-score tool on a sample.
- **Server Action tests:** validation errors, authorization denial, rate limit, and that a mocked `sendEmail` is called once with an idempotency key.

## Tooling
- `react-email` v6: unified components plus `render`, `pretty`, `toPlainText`. Active (released 2026-04-16).
- `@react-email/ui`: preview server (renamed from `@react-email/preview-server`), run via `email dev`. Active.
- `@react-email/components`: superseded by `react-email` in v6. Migrate.
- Tailwind component: bundles Tailwind CSS 4.1.x, with `pixelBasedPreset`.
- Resend (`resend` SDK): Active. Official Next.js guide. Other integrations are documented by React Email: Nodemailer, SendGrid, Postmark, AWS SES, Mailgun, MailerSend, Scaleway, Plunk, Azure.
- caniemail.com: CSS and HTML support per client (community reference).

## Framework Notes
- **Next.js (App Router, 16.3.x):** send from Server Actions or Route Handlers using a `server-only` module. Templates outside `app/` (e.g. `emails/`) keep them from becoming routes. Use `after()` only for non-critical emails. Use a queue (Inngest, Trigger.dev, QStash) for critical or bulk ones. Actions that build JSX must be `.tsx`.
- **React (Vite SPA):** templates can live in a shared package, but rendering and sending must happen in a backend or serverless function. Never ship provider keys to the browser. The preview server runs independently of Vite.

## AI Agent Guidance
- Do: import from `react-email` (v6). Check `package.json` first. If the project pins `@react-email/components`, follow its version or propose the migration.
- Do: include `<Preview>`, `lang`, a plain-text part, `PreviewProps`, and a server-only send wrapper that checks `error`.
- Do: classify each email as critical or non-critical and choose inline, queue, or `after()` to match.
- Don't: hardcode API keys, sender domains, or tokens. Use `process.env.RESEND_API_KEY` and `process.env.EMAIL_FROM`.
- Don't: use unsupported Tailwind utilities (`space-*`, `prose`, hover) or rely on media queries for core layout.
- Verify before done: the template renders in the preview server in light and dark, the unit render test passes, a test send returns an ID, links are absolute HTTPS, and there are no secrets in client bundles.

## Examples
**Receipt email triggered from a Stripe webhook (queued)**
```ts
// inngest/functions/send-receipt.ts
import { inngest } from '@/inngest/client'
import { sendEmail } from '@/lib/email'
import { stripe } from '@/lib/stripe'
import { receiptElement } from '@/emails/receipt-element' // .tsx helper returning <ReceiptEmail .../>

export const sendReceipt = inngest.createFunction(
  { id: 'send-receipt', triggers: { event: 'billing/checkout.fulfilled' } },
  async ({ event, step }) => {
    const session = await step.run('load-session', () =>
      stripe.checkout.sessions.retrieve(event.data.sessionId, { expand: ['line_items'] }),
    )
    await step.run('send', () =>
      sendEmail({
        to: session.customer_details!.email!,
        subject: 'Your Acme receipt',
        template: receiptElement(session),
        idempotencyKey: `receipt:${session.id}`,
      }),
    )
  },
)
```
Check current Inngest docs for the `createFunction` config shape.

**Rendering for a non-Resend provider (SES or Nodemailer)**
```ts
import { render } from 'react-email'
const html = await render(<WelcomeEmail name="Ada" />)
const text = await render(<WelcomeEmail name="Ada" />, { plainText: true })
await transporter.sendMail({ from: process.env.EMAIL_FROM, to, subject: 'Welcome to Acme', html, text })
```

## Related Skills
- [nextjs-server-actions](../nextjs-server-actions/Skill.md): validated, authorized send triggers
- [nextjs-after-and-post-response-work](../nextjs-after-and-post-response-work/Skill.md): deferring vs queueing sends
- [stripe-payments-in-nextjs](../stripe-payments-in-nextjs/Skill.md): receipts and dunning triggers
- [nextjs-authentication](../nextjs-authentication/Skill.md): verification and reset token flows
- [authentication-ux](../authentication-ux/Skill.md): wording and flow of auth emails
- [otp-and-auth-forms](../otp-and-auth-forms/Skill.md): OTP codes delivered by email
- [microcopy-ux-writing](../microcopy-ux-writing/Skill.md): subject lines and CTA text
- [dark-mode-implementation](../dark-mode-implementation/Skill.md): color scheme considerations
- [tailwind-css-v4](../tailwind-css-v4/Skill.md): utility styling used by the Tailwind component
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md): provider key handling
- [vitest-unit-testing](../vitest-unit-testing/Skill.md): render tests
- [visual-regression-testing](../visual-regression-testing/Skill.md): screenshot checks of templates

## Sources
- [React Email: Manual setup](https://react.email/docs/getting-started/manual-setup) (Official): packages, `email dev` script, `emails/` folder
- [React Email: Changelog](https://react.email/docs/changelog) (Official): v6 unification into `react-email`, `@react-email/ui` rename, dark-mode switcher
- [React Email: render utility](https://react.email/docs/utilities/render) (Official): async `render`, `plainText`, `toPlainText`, `data-skip-in-text`
- [React Email: Tailwind component](https://react.email/docs/components/tailwind) (Official): `pixelBasedPreset`, Tailwind 4.1.x, limitations
- [React Email docs index (llms.txt)](https://react.email/docs/llms.txt) (Official): component list and provider integrations
- [Resend: Send with Next.js](https://resend.com/docs/send-with-nextjs) (Official): SDK usage, `RESEND_API_KEY`, `{ data, error }`, idempotency key
- [Resend: Domains](https://resend.com/docs/dashboard/domains/introduction) (Official): subdomain strategy, DMARC and BIMI, custom return path, TLS

## License / Usage Notes
React Email is MIT-licensed (verify in repo). Resend docs are vendor-owned. Content here is summarized, and the code is original. Dark-mode and client-quirk guidance draws on widely documented community knowledge (caniemail.com) and should be checked against current client behavior.

## Quality Tier
B: setup, render, Tailwind, and Resend usage verified against current official docs. Dark-mode and client quirks, bounce-test addresses, and Resend idempotency-key placement are not fully verified and are flagged.

## Status
Active

## Last Verified
2026-09-15
