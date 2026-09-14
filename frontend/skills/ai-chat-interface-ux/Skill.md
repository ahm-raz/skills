# AI Chat Interface UX

## Summary
UX patterns for conversational and agentic AI interfaces: prompt input, streaming responses, stop/regenerate, message actions, reasoning and tool-call visibility, citations, human approval for actions, error and rate-limit states, feedback, and trust calibration. Grounded in Microsoft's Guidelines for Human-AI Interaction (HAX), Google PAIR Guidebook, Apple HIG Generative AI guidance, shapeof.ai patterns, and implemented with Vercel AI SDK UI (`useChat`, AI SDK 5+) and AI Elements in Next.js.

## Category
UX

## Subcategories
chat UI, streaming, prompt input, suggestions, citations/references, reasoning display, tool calls, human-in-the-loop approval, feedback, trust calibration, AI disclosure, generative UI

## Problem It Solves
AI features fail users through blank prompt boxes ("what do I type?"), frozen UIs during generation, no way to stop runaway output, hidden sources, overconfident wrong answers, agents taking actions without consent, lost conversations on errors, and chat bolted on where a button would do.

## When To Use
- Building assistants, copilots, support bots, agentic tools, RAG Q&A, or inline AI features with conversational follow-up.

## When Not To Use
- Deterministic tasks better served by direct UI (filters, forms, buttons). Don't force chat as the only interface for structured actions.
- Where AI output can't be verified and errors are high-stakes, without human review workflows.

## Core Principles
1. **Set expectations** (HAX 1-2): make clear what the AI can do and how well; disclose AI involvement.
2. **Show system status continuously**: submitted -> streaming -> ready/error; stream tokens as they arrive.
3. **Keep users in control**: Stop, edit and resend, regenerate, undo AI changes, and explicit approval before consequential actions.
4. **Calibrate trust, don't maximize it** (PAIR): show sources/citations, uncertainty and limitations; make verification easy.
5. **Fail gracefully**: preserve the prompt, explain, offer retry or alternatives.
6. **Support efficient correction and feedback** (HAX 9, 15): edit, thumbs up/down with reason, report.
7. **Context-aware, not intrusive**: offer AI at the moment of need; allow dismissal.
8. **Privacy and data transparency**: what's stored, used for training, and how to delete.
9. **Chat is a fallback; structured UI is a feature**: render rich components (generative UI) for structured results.

## Best Practices
- Empty conversation: brief capability statement + 3-4 specific starter prompts relevant to user context.
- Input: auto-growing textarea, Enter to send / Shift+Enter newline (and IME composition safe), attachments with previews and limits, model/mode selector only if meaningful.
- While streaming: Send button becomes Stop; input remains editable for the next message; auto-scroll only if user is at bottom (don't yank scroll when reading).
- Messages: clear authorship; markdown rendering with safe sanitization; code blocks with copy; tables; message actions (copy, regenerate, edit, feedback) visible on hover and focus.
- Reasoning/"thinking": collapsed by default with duration ("Thought for 8s"), expandable (shapeof.ai "stream of thought").
- Tool calls: show concise status ("Searching docs...", "Queried 3 tables"), expandable inputs/outputs; errors per tool.
- Human-in-the-loop: consequential tool calls (send email, delete, purchase, write to prod) require explicit approval with a readable summary of what will happen; allow deny with reason.
- Citations: inline numbered references linking to sources with titles/domains; show "No sources found" honestly.
- Errors: inline under the failed message with Retry; distinguish rate limits ("You've reached the limit. Resets at 3:00 PM"), network, content policy, context length.
- Long conversations: persist and resume streams; conversation list with titles; delete/export.
- Disclose limitations near input ("AI can make mistakes. Check important info.") — short, persistent, not a modal.
- Feedback: thumbs + optional reason categories; confirm receipt; never guilt users.

## Implementation Guidance

State -> UI mapping for AI SDK `useChat` (`status`: `'submitted' | 'streaming' | 'ready' | 'error'`):

| status | Input | Primary button | Message list |
|---|---|---|---|
| ready | enabled | Send (disabled if empty) | normal |
| submitted | enabled (queue disabled) | Stop | typing/"Thinking..." indicator |
| streaming | enabled | Stop | streaming content, caret |
| error | enabled, prompt preserved | Send | inline error + Retry (`regenerate`) |

Pattern decision table:

| Need | Pattern |
|---|---|
| Users don't know what to ask | Starter prompts / suggestions |
| Output grounded in documents | Inline citations + sources panel |
| Agent performs multi-step work | Task/plan list with step status |
| Consequential action | Tool approval card (approve/deny) |
| Structured result (flights, charts) | Generative UI component from tool output |
| Compare options | Variations / regenerate with version switcher |
| Long-running agent | Background task + notification; resumable stream |
| Uncertain answer | Confidence language + "verify" affordances + sources |

```tsx
// app/api/chat/route.ts — AI SDK 5+ streaming route (provider-agnostic)
import { streamText, convertToModelMessages, type UIMessage } from "ai";
export const maxDuration = 30;
export async function POST(req: Request) {
  const { messages }: { messages: UIMessage[] } = await req.json();
  const result = streamText({
    model: "provider/model-id", // via AI Gateway or a provider package
    system: "You are a helpful assistant for Acme docs. Cite sources. Say when you don't know.",
    messages: convertToModelMessages(messages),
  });
  return result.toUIMessageStreamResponse({ sendReasoning: true, sendSources: true });
}
```

```tsx
// app/(app)/assistant/chat.tsx
"use client";
import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport } from "ai";
import { useState, useRef, useEffect } from "react";

const starters = ["Summarize this week's incidents", "Draft a release note from merged PRs", "Explain our refund policy"];

export function Chat() {
  const [input, setInput] = useState("");
  const { messages, sendMessage, status, stop, regenerate, error, clearError } = useChat({
    transport: new DefaultChatTransport({ api: "/api/chat" }),
  });
  const busy = status === "submitted" || status === "streaming";
  const endRef = useRef<HTMLDivElement>(null);
  const atBottom = useRef(true);
  useEffect(() => { if (atBottom.current) endRef.current?.scrollIntoView({ block: "end" }); }, [messages]);

  function submit(text: string) {
    if (!text.trim() || busy) return;
    clearError();
    sendMessage({ text });
    setInput("");
  }

  return (
    <div className="flex h-full flex-col">
      <div role="log" aria-live="polite" aria-busy={busy} className="flex-1 overflow-y-auto p-4"
        onScroll={(e) => { const el = e.currentTarget; atBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 40; }}>
        {messages.length === 0 && (
          <div className="mx-auto max-w-lg text-center">
            <h2 className="text-lg font-semibold">Ask about your workspace</h2>
            <p className="text-sm text-neutral-600">I can search docs, incidents and PRs. I can make mistakes, so check important details.</p>
            <ul className="mt-4 grid gap-2">{starters.map((s) => <li key={s}><button className="w-full rounded-md border p-2 text-left" onClick={() => submit(s)}>{s}</button></li>)}</ul>
          </div>
        )}
        {messages.map((m) => (
          <article key={m.id} aria-label={m.role === "user" ? "You" : "Assistant"} className="py-3">
            {m.parts.map((part, i) => {
              switch (part.type) {
                case "text": return <Markdown key={i}>{part.text}</Markdown>;
                case "reasoning": return <details key={i} className="text-sm text-neutral-600"><summary>Reasoning</summary><p className="whitespace-pre-wrap">{part.text}</p></details>;
                case "source-url": return <a key={i} href={part.url} target="_blank" rel="noreferrer" className="mr-2 text-xs underline">{part.title ?? new URL(part.url).hostname}</a>;
                default: return null; // tool parts rendered by typed components (tool-<name>)
              }
            })}
          </article>
        ))}
        {status === "submitted" && <p className="text-sm text-neutral-500">Thinking...</p>}
        {error && (
          <div role="alert" className="rounded-md border border-red-200 bg-red-50 p-3 text-sm">
            The response didn't finish. <button className="underline" onClick={() => regenerate()}>Try again</button>
          </div>
        )}
        <div ref={endRef} />
      </div>

      <form className="border-t p-3" onSubmit={(e) => { e.preventDefault(); submit(input); }}>
        <label htmlFor="prompt" className="sr-only">Message</label>
        <textarea id="prompt" rows={1} value={input} onChange={(e) => setInput(e.target.value)} placeholder="Ask anything"
          onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); submit(input); } }}
          className="w-full resize-none" />
        <div className="flex items-center justify-between">
          <p className="text-xs text-neutral-500">AI can make mistakes. Check important info.</p>
          {busy
            ? <button type="button" onClick={() => stop()} className="btn-secondary">Stop</button>
            : <button type="submit" disabled={!input.trim()} className="btn-primary">Send</button>}
        </div>
      </form>
    </div>
  );
}
```

Tool approval (AI SDK supports tool approval requests; respond with `addToolApprovalResponse({ id, approved, reason })`):

```tsx
function ApprovalCard({ approvalId, summary, onRespond }: { approvalId: string; summary: string; onRespond: (r: { id: string; approved: boolean; reason?: string }) => void }) {
  return (
    <div role="group" aria-label="Action needs approval" className="rounded-md border p-3">
      <p className="font-medium">The assistant wants to:</p>
      <p className="text-sm">{summary /* e.g. "Send email to 42 customers with subject “Outage update”" */}</p>
      <div className="mt-3 flex gap-2">
        <button className="btn-primary" onClick={() => onRespond({ id: approvalId, approved: true })}>Approve and send</button>
        <button className="btn-secondary" onClick={() => onRespond({ id: approvalId, approved: false, reason: "User denied" })}>Don't send</button>
      </div>
    </div>
  );
}
```

AI Elements (shadcn/ui-based registry) provides prebuilt `Conversation`, `Message`, `PromptInput`, `Reasoning`, `Tool`, `Sources`/citations, `Actions`, `Suggestion`, `Loader` components wired for `useChat` — install via its CLI or shadcn CLI and customize (you own the code).

## Recommended Workflow
1. Validate chat is the right interaction; list tasks where structured UI is better.
2. Define capabilities, limitations and disclosure copy; choose starter prompts.
3. Map every status and failure (network, rate limit, moderation, context length, tool failure) to UI.
4. Classify tools by consequence; require approval for consequential ones.
5. Build with AI SDK UI + AI Elements; render typed tool parts as components.
6. Add feedback capture and evaluation logging (with consent and privacy review).
7. Test with real users for trust calibration (do they verify when they should?).
8. Monitor quality, latency (time to first token), stop/regenerate rates, feedback.

## Patterns
- **Starter prompts** in empty conversation.
- **Stop/Send toggle** and resumable streams.
- **Collapsible reasoning** with duration.
- **Tool status chips** expandable to inputs/outputs.
- **Approval card** for consequential actions.
- **Inline citations** with sources list.
- **Edit and resend** user message (branching).
- **Variations / version switcher** for regenerate.
- **Artifacts/canvas**: large outputs (docs, code) in a side panel with edit and versioning.
- **Inline AI** (selection -> "Rewrite", "Summarize") instead of chat where context is clear.

## Anti-Patterns
- **Blank prompt box only** — Fix: capabilities + starters.
- **No Stop button** — users trapped in long generations. Fix: `stop()` always available while busy.
- **Force-scroll during streaming** — can't read. Fix: auto-scroll only when at bottom; "Jump to latest" button.
- **Agents acting without consent** — Fix: approval cards, undo, audit trail.
- **Anthropomorphic overclaiming** ("I understand how you feel") and fake typing delays — erodes calibrated trust. Fix: clear, honest system voice.
- **Hiding sources or fabricating citations** — Fix: render only real retrieved sources; say when none.
- **Losing the prompt on error** — Fix: keep input/message, Retry.
- **Rendering raw model HTML/markdown unsanitized** — XSS. Fix: sanitized markdown renderer, no raw HTML.
- **Chat as the only way to do structured tasks** — Fix: buttons/forms for common actions; generative UI.
- **Dark-pattern engagement** (endless follow-up prompts nudging usage) — Fix: helpful, optional suggestions.

## Accessibility
- Message container `role="log"` with polite announcements; avoid announcing every token — announce on completion or in chunks (screen readers can be overwhelmed by streaming).
- Stop/Send button accessible name changes; focus stays in input after send.
- Keyboard: Enter/Shift+Enter documented; message actions reachable by Tab (not hover-only).
- Code blocks and tables semantic; copy buttons labeled ("Copy code").
- Respect reduced motion for typing animations; don't rely on color for user vs assistant.
- Timeouts/rate limits communicated in text with reset time (2.2.1 considerations).

## Responsive Design
- Mobile: input pinned above keyboard (use `dvh` units and `env(safe-area-inset-bottom)`), conversation list in drawer, artifacts full-screen sheet.
- Message actions visible (not hover) on touch.

## Performance
- Stream responses (lower time-to-first-token perception); virtualize very long threads; memoize rendered markdown for completed messages; throttle UI updates during streaming (`experimental_throttle` in `useChat`).
- Lazy-load heavy renderers (syntax highlighting, math, mermaid) with `next/dynamic`.

## Security
- Treat model output as untrusted: sanitize markdown, block `javascript:` links, add `rel="noreferrer"` on external links, no raw HTML rendering.
- Prompt injection: tool approvals for side effects; never let model output directly trigger privileged actions; scope tool permissions to the user.
- Keep API keys server-side (route handlers); rate-limit per user; content moderation where needed.
- Privacy: disclose data retention/training use; allow deleting conversations; redact PII in logs.

## Testing
- Mock streams with AI SDK test utilities (`MockLanguageModelV2` / `simulateReadableStream`) to test streaming, stop, error, tool approval UI deterministically.
- Playwright: send, stop mid-stream, network error -> retry, approval approve/deny paths, keyboard-only use.
- Evals for response quality separately from UI tests; accessibility test with NVDA/VoiceOver during streaming.

## Tooling
- Vercel AI SDK (`ai`, `@ai-sdk/react`) v5+ with `useChat`, transports, tool approval; AI Elements (shadcn/ui registry, MIT); assistant-ui (open source React chat primitives); react-markdown + rehype-sanitize or Streamdown for streaming-safe markdown; Langfuse/LangSmith for traces and feedback.

## Framework Notes
- **Next.js (App Router)**: Route Handler (`app/api/chat/route.ts`) streams `toUIMessageStreamResponse()`; persist chats in DB with `onFinish`; load history in Server Component and pass `messages` as initial; `maxDuration` for serverless limits; server-side auth on the route.
- **React (Vite SPA)**: same `useChat` hook against any backend endpoint implementing the UI message stream protocol (Node/Express/Hono); keep provider keys on the server.

## AI Agent Guidance
- Do: implement all four statuses, Stop, Retry, starters, disclosure line, sanitized markdown, approval for side-effect tools; keep keys server-side.
- Don't: auto-execute consequential tools; don't force-scroll; don't render raw HTML; don't hide errors.
- Verify: simulate slow stream, mid-stream stop, 429 and 500 errors, keyboard-only flow, screen reader announcement behavior, mobile keyboard overlap.

## Examples
```tsx
// Jump-to-latest button when user scrolled up during streaming
{!atBottomState && busy && (
  <button className="fixed bottom-24 right-6 rounded-full border bg-white px-3 py-1 text-sm shadow" onClick={() => endRef.current?.scrollIntoView({ behavior: "smooth" })}>
    Jump to latest
  </button>
)}
```

## Related Skills
- [vercel-ai-sdk-integration](../vercel-ai-sdk-integration/Skill.md) — SDK setup, providers, tools
- [loading-states](../loading-states/Skill.md) — streaming and pending feedback
- [error-states](../error-states/Skill.md) — failure messaging
- [destructive-actions-and-confirmation](../destructive-actions-and-confirmation/Skill.md) — approval for consequential actions
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — announcing streamed content
- [shadcn-ui](../shadcn-ui/Skill.md) — AI Elements foundation
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — streaming endpoints
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — sanitizing untrusted output

## Sources
- [Microsoft HAX Toolkit: Guidelines for Human-AI Interaction](https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/) — Official — 18 guidelines across initial, during interaction, when wrong, over time
- [Google PAIR People + AI Guidebook](https://pair.withgoogle.com/guidebook-v2/) — Official (CC BY) — explainability + trust, feedback + control, errors + graceful failure
- [Apple HIG: Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) — Official — transparency, user control
- [AI SDK UI: useChat reference](https://ai-sdk.dev/docs/reference/ai-sdk-ui/use-chat) — Official (Open Source) — status values, stop, regenerate, addToolApprovalResponse
- [vercel/ai-elements](https://github.com/vercel/ai-elements) — Open Source — component families for AI interfaces
- [shapeof.ai AI UX patterns](https://www.shapeof.ai/) — Community — stream of thought, references, variations, modes, parameters
- [shadcn/ui changelog: chat components (June 2026)](https://ui.shadcn.com/docs/changelog/2026-06-chat-components) — Open Source — Message, Bubble, Attachment components

## License / Usage Notes
AI SDK and AI Elements are open source (Apache-2.0 / MIT per repos — verify); PAIR guidebook CC BY; HAX and Apple HIG summarized. Code original and provider-agnostic; model ID is a placeholder.

## Quality Tier
A — official human-AI guidelines and verified current SDK APIs; the field and SDK APIs evolve quickly (re-verify quarterly).

## Status
Active

## Last Verified
2026-09-15
