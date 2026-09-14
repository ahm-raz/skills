# Vercel AI SDK Integration (Next.js)

## Summary
Building AI features in Next.js with the AI SDK 7 (`ai`, `@ai-sdk/react`): streaming chat via a Route Handler with `streamText` and UI message streams, the `useChat` hook with message `parts`, server and client tools with approval, multi-step agents (`stopWhen: isStepCount(n)`), structured output, AI Elements (shadcn/ui-based) for chat UI, and the production concerns: auth, rate limiting, cost limits, key security, persistence, and testing.

## Category
Next.js

## Subcategories
AI SDK Core, AI SDK UI, streaming, tool calling, generative UI, AI Gateway, AI Elements, rate limiting, prompt injection, chat persistence

## Problem It Solves
AI features are easy to demo and hard to ship: leaked provider keys, unauthenticated endpoints running up bills, unbounded tool loops, broken streaming UIs, outdated SDK v3/v4 examples (`StreamingTextResponse`, `input`/`handleSubmit`, `maxSteps`), inaccessible chat markup, and prompt-injection-driven tool misuse. This skill encodes a current, safe baseline.

## When To Use
- Chat assistants, copilots, and support bots in a Next.js app.
- Streaming text generation (summaries, drafts) and structured extraction.
- Tool-using agents that read/write app data on behalf of a user.

## When Not To Use
- Batch/offline pipelines with no UI (use AI SDK Core in background jobs/queues; this skill's UI parts do not apply).
- Apps standardized on another orchestration stack; still apply the security sections.
- Chat UX design decisions (see [ai-chat-interface-ux](../ai-chat-interface-ux/Skill.md)).

## Core Principles
1. Model calls run on the server only; provider/Gateway keys are server-only env vars.
2. Every AI endpoint authenticates the user, enforces rate and token/cost limits, and bounds steps and output.
3. Stream to the client; render `message.parts`, not a single `content` string.
4. Tools are privileged server functions: validate inputs with schemas, authorize per user, require approval for side effects.
5. Treat model output and retrieved content as untrusted input (prompt injection, XSS in rendered markdown).
6. Put system guidance in `instructions` (v7), not in client-supplied messages.
7. Persist conversations server-side keyed by authenticated user; never trust client-sent history for authorization.

## Best Practices
- Verify the installed major version before writing code (`npm ls ai`); AI SDK 7 is ESM-only and requires Node 22+.
- Use a Route Handler `app/api/chat/route.ts` exporting `POST` and `export const maxDuration = 30` (or higher per platform) for streaming.
- Convert UI messages with `await convertToModelMessages(messages)`; return `createUIMessageStreamResponse({ stream: toUIMessageStream({ stream: result.stream }) })` (v7 stateless helpers; the older `result.toUIMessageStreamResponse()` is deprecated).
- Use `stopWhen: isStepCount(5)` (v7 name; `stepCountIs` in v5/v6) to bound tool loops.
- Use Vercel AI Gateway model strings (`'provider/model'`) with `AI_GATEWAY_API_KEY`, or provider packages (`@ai-sdk/openai`, `@ai-sdk/anthropic`) with their server env keys.
- Client: `const { messages, sendMessage, status, stop, regenerate, error } = useChat()`; manage the input with your own `useState` (v5+ removed built-in `input`/`handleSubmit`).
- Configure requests via `transport: new DefaultChatTransport({ api, headers, body, credentials })`.
- Throttle UI updates for long streams (`experimental_throttle`/`throttle` option per installed version) to protect INP.
- Show `status` states: `submitted` (waiting), `streaming`, `ready`, `error`; provide Stop and Retry.
- Tool UI: render `part.type === 'tool-<name>'` by `part.state` (`input-streaming`, `input-available`, `approval-requested`, `output-available`, `output-error`, `output-denied`).
- For client-side tools use `onToolCall` + `addToolOutput` (renamed from `addToolResult`) and `sendAutomaticallyWhen: lastAssistantMessageIsCompleteWithToolCalls`.
- Require human approval for tools with side effects (`toolApproval` in `streamText`; `addToolApprovalResponse` on the client).
- Use AI Elements (shadcn/ui registry components: Conversation, Message, PromptInput, Reasoning, Tool, Sources, etc.) to avoid hand-building streaming chat UI; they are copied into your codebase and themeable.
- Render markdown with a sanitizing renderer (AI Elements' response/markdown components or `react-markdown` without raw HTML).
- Log usage (`result.usage` spans all steps in v7) and attach user/org IDs for cost attribution; enable `telemetry` deliberately.

## Implementation Guidance

### Version map (flag outdated code)
| Concept | v3/v4 (outdated) | v5/v6 | v7 (current) |
|---|---|---|---|
| Response helper | `StreamingTextResponse`, `toDataStreamResponse()` | `result.toUIMessageStreamResponse()` | `createUIMessageStreamResponse({ stream: toUIMessageStream({ stream: result.stream }) })` |
| Step limit | `maxSteps` | `stopWhen: stepCountIs(n)` | `stopWhen: isStepCount(n)` |
| Tool schema | `parameters` | `inputSchema` | `inputSchema` |
| System prompt | `system` | `system` | `instructions` (system messages in `messages` rejected by default) |
| Completion callback | `onFinish` | `onFinish` | `onEnd` (`onStepEnd` per step) |
| Client input | `input`, `handleInputChange`, `handleSubmit` | own state + `sendMessage({ text })` | same |
| Message content | `message.content` | `message.parts` | `message.parts` |
| Client tool result | `addToolResult` | `addToolResult` | `addToolOutput` |
| Full stream | `result.fullStream` | `result.fullStream` | `result.stream` |
| RSC streaming UI | `ai/rsc` `streamUI` | experimental/paused | Prefer `useChat` + typed tool parts |

### Route handler (v7)
```ts
// src/app/api/chat/route.ts
import {
  streamText, convertToModelMessages, createUIMessageStreamResponse, toUIMessageStream,
  isStepCount, tool, type UIMessage,
} from 'ai'
import { z } from 'zod'
import { getSession } from '@/server/auth'
import { rateLimitChat } from '@/server/rate-limit'
import { searchOrdersForUser } from '@/server/orders'

export const maxDuration = 30

const Body = z.object({ messages: z.array(z.custom<UIMessage>()).max(100) })

export async function POST(req: Request) {
  const session = await getSession()
  if (!session?.user) return new Response('Unauthorized', { status: 401 })

  const limit = await rateLimitChat(session.user.id)
  if (!limit.success) return new Response('Too many requests', { status: 429 })

  const parsed = Body.safeParse(await req.json())
  if (!parsed.success) return new Response('Bad request', { status: 400 })

  const userId = session.user.id
  const result = streamText({
    model: process.env.CHAT_MODEL_ID!, // e.g. an AI Gateway 'provider/model' id configured per environment
    instructions: 'You are the order-support assistant. Only discuss the signed-in user\'s orders.',
    messages: await convertToModelMessages(parsed.data.messages),
    stopWhen: isStepCount(5),
    maxOutputTokens: 1_000,
    tools: {
      searchOrders: tool({
        description: 'Search the current user\'s orders by status or keyword',
        inputSchema: z.object({ query: z.string().max(200), status: z.enum(['open', 'shipped', 'cancelled']).optional() }),
        execute: async ({ query, status }) => searchOrdersForUser(userId, { query, status }), // authz via closure userId, not model input
      }),
    },
    abortSignal: req.signal,
  })

  return createUIMessageStreamResponse({ stream: toUIMessageStream({ stream: result.stream }) })
}
```
Verify each identifier against the installed version's docs (`node_modules/ai` README or ai-sdk.dev); v7 renamed several APIs.

### Chat client
```tsx
// src/app/support/chat.tsx
'use client'
import { useState } from 'react'
import { useChat } from '@ai-sdk/react'
import { DefaultChatTransport } from 'ai'

export function SupportChat() {
  const [input, setInput] = useState('')
  const { messages, sendMessage, status, stop, regenerate, error } = useChat({
    transport: new DefaultChatTransport({ api: '/api/chat' }),
  })
  const busy = status === 'submitted' || status === 'streaming'

  return (
    <section aria-labelledby="chat-title">
      <h2 id="chat-title">Order support</h2>
      <ol aria-live="polite" aria-busy={busy}>
        {messages.map(m => (
          <li key={m.id}>
            <span className="sr-only">{m.role === 'user' ? 'You said' : 'Assistant said'}:</span>
            {m.parts.map((part, i) => {
              if (part.type === 'text') return <p key={i}>{part.text}</p>
              if (part.type === 'tool-searchOrders') {
                if (part.state === 'output-available') return <p key={i}>Found {Array.isArray(part.output) ? part.output.length : 0} orders.</p>
                if (part.state === 'output-error') return <p key={i} role="alert">Order search failed.</p>
                return <p key={i}>Searching orders…</p>
              }
              return null
            })}
          </li>
        ))}
      </ol>

      {error && (
        <div role="alert">
          Something went wrong. <button type="button" onClick={() => regenerate()}>Retry</button>
        </div>
      )}

      <form
        onSubmit={e => {
          e.preventDefault()
          const text = input.trim()
          if (!text || busy) return
          sendMessage({ text })
          setInput('')
        }}
      >
        <label htmlFor="chat-input">Message</label>
        <textarea id="chat-input" value={input} maxLength={4000} onChange={e => setInput(e.target.value)} />
        {busy
          ? <button type="button" onClick={stop}>Stop</button>
          : <button type="submit" disabled={!input.trim()}>Send</button>}
      </form>
    </section>
  )
}
```
Chat inherently requires JS; provide a non-JS fallback link (e.g., contact form) if the feature is critical.

### Rate limiting (example with Upstash)
```ts
// src/server/rate-limit.ts
import 'server-only'
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(20, '10 m'),
  prefix: 'chat',
})

export const rateLimitChat = (userId: string) => ratelimit.limit(userId)
```
Also enforce per-user daily token budgets using stored `usage` and provider-side spend limits.

### Decision table: which API?
| Need | Use |
|---|---|
| Streaming chat with history and tools | Route Handler + `streamText` + `useChat` |
| One-shot streaming text (summarize this doc) | `streamText` + `useCompletion` or UI message stream |
| Structured data extraction | `generateText` with `output` (e.g., `Output.object({ schema })`) — `generateObject` is deprecated since v6; verify in installed docs |
| Background/batch generation | `generateText` in a queue/cron job, not a request handler |
| Form-triggered non-streaming generation | Server Action calling `generateText` (auth + limits inside) |
| Chat UI components | AI Elements (shadcn/ui registry) |

## Recommended Workflow
1. Confirm AI SDK version and Node 22+; read the matching docs/migration guide.
2. Define use case, model, max tokens, step limit, and cost budget.
3. Implement the DAL functions tools will call, with per-user authorization.
4. Build the Route Handler: auth, rate limit, body validation, `instructions`, tools, `stopWhen`, abort signal.
5. Build the client with `useChat` (or AI Elements), rendering parts and statuses, Stop/Retry.
6. Add approval flows for side-effect tools.
7. Persist messages server-side (load by chat ID + user ID); validate ownership on load.
8. Add observability (usage, latency, errors, tool calls) and red-team prompts for injection.
9. Test with mock models and e2e.

## Patterns
- **Authenticated streaming route** with rate limit + step/token bounds.
- **User-scoped tools**: capture `userId` from the session in tool closures; never accept user IDs from model input.
- **Human-in-the-loop approval** for writes (refunds, emails, deletions).
- **Typed tool parts rendering** via `tool-<name>` part types and state switch.
- **Chat persistence**: `id` per chat, store UI messages after the stream ends, load in a Server Component and pass as initial `messages`.
- **Retrieval with citations**: return `source-url`/`source-document` parts and render them with AI Elements Sources.
- **Model routing via env**: model IDs in env/config so environments can switch models without code changes.

## Anti-Patterns
- **Calling providers from the browser or `NEXT_PUBLIC_OPENAI_API_KEY`.** Key theft. Fix: server-only env + Route Handler.
- **Unauthenticated `/api/chat`.** Anyone can spend your budget. Fix: session check + rate limit.
- **No `stopWhen`/token cap with tools.** Runaway loops and costs. Fix: `isStepCount`, `maxOutputTokens`, timeouts.
- **Trusting tool input for identity** (`userId` in schema). Fix: bind identity server-side.
- **Rendering model output with `dangerouslySetInnerHTML`** or markdown with raw HTML enabled. XSS. Fix: sanitized markdown renderer.
- **Using v4 examples** (`StreamingTextResponse`, `handleSubmit`, `maxSteps`, `parameters`, `message.content`). Fix: version map above.
- **Accepting system messages from the client.** Prompt override. Fix: `instructions` server-side; v7 rejects system messages in `messages` by default — keep it that way.
- **Re-rendering the whole page on every token.** INP issues. Fix: isolate chat in a client leaf, memoize message rows, throttle.
- **Persisting only client-side (localStorage).** Loss and tampering. Fix: server persistence tied to user.

## Accessibility
- Message list: use a semantic list; announce new assistant content politely without re-announcing entire history (a separate `role="status"` summarizing "Assistant is responding"/"Response complete" is often better than `aria-live` on the full list for long streams).
- Label the input; keep Send/Stop buttons keyboard-accessible and focus stable (WCAG 2.1.1, 2.4.3).
- Provide text alternatives for tool results rendered as rich UI.
- Respect reduced motion for typing indicators (WCAG 2.3.3).
- Errors use `role="alert"` with a Retry control (WCAG 3.3.1, 4.1.3).
- See [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) and [ai-chat-interface-ux](../ai-chat-interface-ux/Skill.md).

## Responsive Design
- Chat layouts: sticky input at bottom with safe-area insets on mobile; avoid fixed heights that break with virtual keyboards (use `dvh` units).
- Long code blocks scroll horizontally within the message, not the page.
- Collapse tool/reasoning details behind disclosures on small screens.

## Performance
- Stream responses to reduce time-to-first-token perception; show `submitted` state immediately.
- Keep the chat component a small client island; do not make the page layout a Client Component.
- Throttle streaming renders and memoize message components; virtualize very long histories ([list-virtualization](../list-virtualization/Skill.md)).
- Set `maxDuration` appropriate to the platform; use `abortSignal: req.signal` so aborted clients stop generation (and cost).
- Cache deterministic, non-personal generations (e.g., product summaries) server-side.

## Security
- Keys: server-only env vars (`AI_GATEWAY_API_KEY` or provider keys), rotated, scoped, with provider spend limits. Never log them.
- AuthN/AuthZ on every AI route and inside every tool.
- Rate limits per user/IP and token budgets per user/org.
- Prompt injection: treat retrieved documents, web content, and user messages as untrusted; restrict tool capabilities; require approval for side effects; never let model output choose authorization scope.
- Output handling: sanitize markdown/HTML; validate structured output with schemas before use; never `eval` generated code.
- Data protection: avoid sending secrets/PII to models unless contracts permit; redact logs; honor data retention settings.
- Validate request bodies (size limits on messages and attachments; file type checks).
- Telemetry is opt-out by default in v7 — review what is collected and configure it deliberately.

## Testing
- Unit test route logic with mock language models (`ai/test` utilities such as mock models and simulated streams — verify names in installed version) to avoid network calls and nondeterminism.
- Test tools' `execute` functions directly with authorized/unauthorized users.
- Component tests render parts for each tool state.
- E2E (Playwright) against a mocked model endpoint: send message, see streaming text, stop, retry, error states.
- Evals: maintain a prompt/answer regression suite (including injection attempts) run in CI or nightly.
- Load test rate limits and `429` UX.

## Tooling
| Tool | Status (2026-09) | Notes |
|---|---|---|
| `ai` (AI SDK 7) | Active | ESM-only, Node 22+; v6 -> v7 migration guide |
| `@ai-sdk/react` | Active | `useChat`, `useCompletion` |
| Vercel AI Gateway | Active | `provider/model` ids, `AI_GATEWAY_API_KEY` |
| Provider packages (`@ai-sdk/openai`, `@ai-sdk/anthropic`, ...) | Active | Direct provider access |
| AI Elements | Active | shadcn/ui-based chat/agent components |
| `@ai-sdk/otel` | Active | OpenTelemetry integration (moved out of core in v7) |
| `@upstash/ratelimit` | Community, active | Serverless rate limiting |
| `ai/rsc` (`streamUI`) | Not recommended for new code | Prefer `useChat` + tool parts |
| `StreamingTextResponse`, `useChat` `input`/`handleSubmit` | Removed/outdated | — |

## Framework Notes
- **Next.js**: Route Handlers for streaming chat (`maxDuration`), Server Components to load persisted chats, Server Actions for non-streaming generation. Keep AI routes on the Node.js runtime unless a provider requires otherwise. Protect routes in the handler, not only in `proxy.ts`.
- **React (Vite SPA)**: `useChat` works with any backend endpoint that returns a UI message stream (Hono/Express/Fastify using AI SDK Core). Configure `DefaultChatTransport` `api` and `credentials: 'include'` for cookie auth; never call providers directly from the SPA.

## AI Agent Guidance
- Do: check `package.json` for the `ai` major version and read its docs/migration guide before writing code.
- Do: include auth, rate limiting, `stopWhen`, token caps, and input validation in every AI route you create.
- Do: render `message.parts` and all tool states; add Stop and Retry.
- Don't: expose keys, accept identity from model/tool inputs, or render raw HTML from model output.
- Don't: copy v3/v4 snippets (`StreamingTextResponse`, `handleSubmit`, `maxSteps`, `parameters`).
- Before done: typecheck passes; unauthenticated request returns 401; rate limit returns 429; stopping a stream aborts server generation; no key strings appear in client bundles (`grep` build output for key prefixes).

## Examples
```tsx
// Tool approval UI (client) — side-effect tool
{m.parts.map((part, i) => {
  if (part.type !== 'tool-issueRefund') return null
  if (part.state === 'approval-requested') {
    return (
      <div key={i} role="group" aria-label="Refund approval">
        <p>Issue a refund of {part.input.amount} for order {part.input.orderId}?</p>
        <button onClick={() => addToolApprovalResponse({ id: part.approval.id, approved: true })}>Approve</button>
        <button onClick={() => addToolApprovalResponse({ id: part.approval.id, approved: false })}>Deny</button>
      </div>
    )
  }
  if (part.state === 'output-denied') return <p key={i}>Refund cancelled.</p>
  if (part.state === 'output-available') return <p key={i}>Refund issued.</p>
  return null
})}
// Exact approval object shape varies by version; confirm in ai-sdk.dev chatbot tool usage docs.
```

```ts
// Server Action: non-streaming structured summary
'use server'
import { generateText, Output } from 'ai'
import { z } from 'zod'
import { requireUser } from '@/server/auth'

export async function summarizeTicket(ticketText: string) {
  await requireUser()
  const { output } = await generateText({
    model: process.env.SUMMARY_MODEL_ID!,
    instructions: 'Summarize support tickets neutrally.',
    prompt: ticketText.slice(0, 8_000),
    output: Output.object({ schema: z.object({ summary: z.string().max(500), sentiment: z.enum(['positive', 'neutral', 'negative']) }) }),
  })
  return output
}
```

## Related Skills
- [ai-chat-interface-ux](../ai-chat-interface-ux/Skill.md) — conversational UX patterns
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — streaming responses and handler patterns
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — non-streaming generation
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — key management
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — XSS and injection handling
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — accessible streaming updates
- [shadcn-ui](../shadcn-ui/Skill.md) — base for AI Elements
- [nextjs-database-integration](../nextjs-database-integration/Skill.md) — tools calling the DAL and chat persistence

## Sources
- [AI SDK: Next.js App Router quickstart](https://ai-sdk.dev/docs/getting-started/nextjs-app-router) — Official — v7 route handler, useChat, tools, isStepCount, AI Gateway env
- [AI SDK: Migration guide 6.x to 7.0](https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0) — Official — renamed APIs (instructions, onEnd, result.stream, UI stream helpers), Node 22, ESM-only
- [AI SDK UI: Chatbot](https://ai-sdk.dev/docs/ai-sdk-ui/chatbot) — Official — useChat returns, status values, DefaultChatTransport, parts
- [AI SDK UI: Chatbot tool usage](https://ai-sdk.dev/docs/ai-sdk-ui/chatbot-tool-usage) — Official — onToolCall, addToolOutput, tool states, approvals
- [AI Elements](https://elements.ai-sdk.dev/) — Official — shadcn/ui-based AI component library
- [Next.js Data Security](https://nextjs.org/docs/app/guides/data-security) — Official — server-only secrets, auth in server entry points

## License / Usage Notes
AI SDK and AI Elements are Apache-2.0/MIT (check package licenses). Content summarized from official docs; code is original and must be validated against the installed AI SDK version because APIs change across majors.

## Quality Tier
A — Based on current v7 official docs and migration guide; some fine-grained identifiers (approval part shape, throttle option name, structured output helper) change between minors and are flagged for verification.

## Status
Active

## Last Verified
2026-09-15
