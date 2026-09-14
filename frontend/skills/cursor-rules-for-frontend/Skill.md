# Cursor Rules for Frontend (React + Next.js)

## Summary
How to write, scope and maintain Cursor project rules (`.cursor/rules/*.mdc`) and `AGENTS.md` for a React + Next.js App Router + TypeScript + Tailwind/shadcn codebase. It covers the `.mdc` frontmatter (`description`, `globs`, `alwaysApply`), the four activation types, sizing, and a ready-to-adapt rule set. It also explains why most copy-paste community rule files are outdated and should be distilled, not installed.

## Category
AI Agent Workflows

## Subcategories
Cursor, project rules, .mdc, AGENTS.md, context engineering, Next.js App Router conventions, Tailwind/shadcn conventions, rule hygiene

## Problem It Solves
Cursor's agent falls back on its training data. For Next.js, that data is heavy with Pages Router, `getServerSideProps`, sync `params`, `middleware.ts` and Next 13/14 caching defaults. Without scoped rules the agent adds `"use client"` everywhere, reaches for `useEffect` fetching, creates barrel files, uses `transition-all`, and ignores your design tokens. Community `.cursorrules` files often make this worse: they are long persona prompts ("You are an expert senior developer…"), pinned to old versions, and applied globally, which wastes context and contradicts current APIs.

## When To Use
- Setting up or auditing Cursor on a React/Next.js repo.
- Teammates use Cursor alongside Claude Code, Copilot or Codex and you need consistent conventions.
- The agent keeps repeating the same mistake (wrong import path, client component sprawl, raw hex colors).
- Migrating a legacy root `.cursorrules` file to scoped `.mdc` rules.

## When Not To Use
- Rules that a linter, formatter or type checker can enforce. Use ESLint/Prettier/`tsc` and tell the agent to run them.
- One-off task instructions. Put them in the chat prompt.
- Long API documentation. Point at bundled docs (`node_modules/next/dist/docs/`) or reference a canonical file with `@file` instead of pasting.
- Personal preferences (tone, verbosity). Put these in User Rules, not the repo.

## Core Principles
1. **Scope beats size.** Every always-on line costs tokens in every request. Attach rules by glob or description whenever possible.
2. **Only write what the model can't infer.** Leave out "write clean code". Keep project-specific paths, commands, versions and forbidden patterns.
3. **Version-accurate over generic.** State the Next.js/React/Tailwind major versions and send the agent to version-matched docs.
4. **Point to canonical examples.** `@components/ui/button.tsx` is worth ten sentences describing button conventions.
5. **Rules are code.** Commit, review, prune and test them by watching whether behaviour actually changes.
6. **Single source of truth.** Keep cross-tool facts in `AGENTS.md`. Put only Cursor-specific scoping in `.mdc`.

## Best Practices
- Keep each rule under about 500 lines (Cursor's guidance). In practice aim for 20–80 lines per rule and split large rules into composable ones.
- Use one always-apply rule at most, a short project baseline. Everything else should be glob-attached or agent-requested.
- Write `description` as a trigger sentence ("Use when creating or editing React components in components/ or app/"). Agent-requested rules are chosen by it.
- Globs are comma-separated. `**` is recursive. Test that a rule attaches by opening a matching file and checking the active rules in chat.
- Phrase rules as verifiable imperatives with a reason: "Do not add `'use client'` to `page.tsx`/`layout.tsx`; push interactivity into leaf components (keeps the RSC payload and JS bundle small)."
- Include the verification commands (`pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm build`) so the agent closes its own loop.
- Delete rules the agent already follows without them.
- Never put secrets, tokens or internal URLs with credentials in rules. They are committed and sent to the model.

## Implementation Guidance

### File locations and types
| Mechanism | Location | Loaded |
|---|---|---|
| Project rules | `.cursor/rules/*.mdc` (subfolders allowed; nested `.cursor/rules` in subdirectories scope to that folder) | Per frontmatter |
| AGENTS.md | repo root and subdirectories, plain markdown, no frontmatter | Always / nearest directory |
| User Rules | Cursor settings (Customize) | All projects, chat only |
| Team Rules | Cursor dashboard (Team/Enterprise), can be enforced | Org-wide |
| Legacy `.cursorrules` | repo root | Deprecated. Migrate |

Plain `.md` files inside `.cursor/rules` are ignored (only `.mdc`). The exception is `AGENTS.md`.

### Activation types from frontmatter
| Type | Frontmatter | Use for |
|---|---|---|
| Always Apply | `alwaysApply: true` | Tiny project baseline (stack, commands, hard bans) |
| Apply Intelligently (agent-requested) | `alwaysApply: false`, `description` set, no globs | Workflows and topics that match intent ("writing tests", "adding a route") |
| Apply to Specific Files (auto-attached) | `globs: "app/**/*.tsx, components/**/*.tsx"` | File-type conventions |
| Apply Manually | no description, no globs, `alwaysApply: false` | Rarely needed playbooks invoked with `@rule-name` |

Create rules with `/create-rule` in chat or the Customize panel. Review the output, which is usually too verbose.

### Recommended layout for a Next.js App Router repo
```
AGENTS.md                         # cross-tool: stack, commands, structure, bans
.cursor/rules/
  00-project.mdc                  # alwaysApply, ≤30 lines, points to AGENTS.md
  nextjs-app-router.mdc           # globs: app/**
  react-components.mdc            # globs: components/**, app/**/*.tsx
  tailwind-shadcn.mdc             # globs: **/*.tsx, app/globals.css
  testing.mdc                     # globs: **/*.test.tsx, e2e/**
  data-and-server-actions.mdc     # description-triggered
```

### Migration from `.cursorrules`
1. Delete persona text, generic advice, and anything a linter enforces.
2. Check every version-specific claim against current docs (Next 15/16: async `params`/`searchParams`/`cookies()`/`headers()`; `middleware` renamed to `proxy` in Next 16; `use cache`/Cache Components; Turbopack default; ESLint CLI instead of `next lint`).
3. Split what remains by file area into `.mdc` files with globs.
4. Move cross-tool facts to `AGENTS.md`.
5. Remove `.cursorrules`.

## Recommended Workflow
1. Run the agent on 3 representative tasks with no rules (new route, new form component, restyle a page). Record its mistakes.
2. Write `AGENTS.md` (stack + versions, commands, folder map, hard bans).
3. Add a ≤30-line `00-project.mdc` with `alwaysApply: true` that references `@AGENTS.md` only if Cursor isn't already loading it.
4. Add one glob-scoped rule per recorded mistake cluster, each with a canonical `@file` example.
5. Re-run the same 3 tasks and confirm the mistakes are gone. Remove rules that made no difference.
6. Review rules in PRs like code. Revisit them after every framework major upgrade.

## Patterns

### Pattern: Thin always-on baseline
```mdc
---
description: Project baseline for all work in this repository
alwaysApply: true
---
- Stack: Next.js 16 App Router, React 19, TypeScript strict, Tailwind v4, shadcn/ui, pnpm.
- Before writing Next.js code, read the relevant guide in node_modules/next/dist/docs/.
- Done = `pnpm typecheck && pnpm lint && pnpm test` pass; for UI changes also check the page in the browser.
- Never edit .env*, never print secret values, never add dependencies without asking.
```

### Pattern: Glob-attached framework rule (`nextjs-app-router.mdc`)
```mdc
---
description: Next.js App Router conventions for routes, layouts, data fetching and caching
globs: app/**/*.ts, app/**/*.tsx
alwaysApply: false
---
# App Router
- Components are Server Components by default. Add 'use client' only to leaf components that need state, effects, refs or browser APIs.
- `params` and `searchParams` are Promises: `const { slug } = await params`.
- `cookies()`, `headers()`, `draftMode()` are async; reading them makes the route dynamic, so isolate them behind <Suspense>.
- Fetch data in Server Components or `lib/data/*` (import 'server-only'). Do not call our own Route Handlers from Server Components.
- Mutations: Server Actions in `app/**/actions.ts` with 'use server'. Validate input with zod and check auth inside every action.
- Caching: 'use cache' + cacheTag/cacheLife; revalidateTag in actions. Do not use unstable_cache in new code.
- Every data route segment gets loading.tsx or a <Suspense> boundary and an error.tsx.
- Request interception lives in proxy.ts (Next 16), not middleware.ts.
- Metadata via `export const metadata` / `generateMetadata`, never manual <head>.
- Images: next/image with width/height or fill+sizes. Fonts: next/font.
- Example route: @app/(dashboard)/projects/[id]/page.tsx
```

### Pattern: Component rule (`react-components.mdc`)
```mdc
---
description: React component authoring rules
globs: components/**/*.tsx, app/**/*.tsx
alwaysApply: false
---
- Named function components with a `Props` type; no React.FC; no default exports except Next.js route files.
- React 19: pass `ref` as a prop (no forwardRef); use `use()` for context/promises where appropriate.
- Prefer composition (children, compound components) over boolean-prop explosions (`isCompact`, `hasIcon`...).
- Derive state during render; don't mirror props into state; no useEffect for data fetching or derived values.
- Import directly from the module (`@/components/ui/button`), not from barrel index files.
- Semantics first: <button> for actions, <Link>/<a> for navigation, never <div onClick>.
- Icon-only buttons need aria-label; decorative icons aria-hidden.
- Canonical example: @components/projects/project-card.tsx
```

### Pattern: Styling rule (`tailwind-shadcn.mdc`)
```mdc
---
description: Tailwind v4 and shadcn/ui usage
globs: **/*.tsx, app/globals.css
alwaysApply: false
---
- Use semantic tokens (bg-background, text-muted-foreground, border-border, bg-primary). No raw hex or arbitrary colors unless adding a token in app/globals.css (@theme).
- Compose classes with cn() from @/lib/utils; variants via cva, not string concatenation.
- Add shadcn components with `pnpm dlx shadcn@latest add <name>`; edit the generated file in components/ui rather than wrapping it in ad-hoc overrides.
- Never `transition-all`; list properties (transition-[opacity,transform]); respect motion-reduce:.
- Never remove focus outlines without a focus-visible: replacement.
- Mobile-first: base classes for small screens, then sm:/md:/lg:. Inputs text-base on mobile (prevents iOS zoom).
- Dark mode via tokens, not duplicated dark: color literals.
```

### Pattern: Testing rule (`testing.mdc`)
```mdc
---
description: Unit, component and e2e test conventions
globs: **/*.test.ts, **/*.test.tsx, e2e/**/*.ts
alwaysApply: false
---
- Unit/component: Vitest + Testing Library. Query by role/label (getByRole), never by class or test-id unless unavoidable.
- Async Server Components are not unit-testable with RTL; cover them with Playwright e2e.
- Mock network with MSW handlers in test/msw/, not by mocking fetch per test.
- E2E: Playwright in e2e/, use role locators, no fixed sleeps; include an @axe-core/playwright check on new pages.
- Run the single relevant test file first (`pnpm vitest run path`), then the suite.
```

## Anti-Patterns
- **Persona preambles** ("You are a senior expert in Next.js, React, …"). They add tokens but no constraints. Replace them with concrete rules.
- **One giant always-apply file** pasted from awesome-cursorrules. It dilutes adherence and conflicts with your stack. Split it and scope by glob.
- **Stale version rules** (Pages Router, `getStaticProps`, sync `params`, "fetch is cached by default", `middleware.ts` in Next 16, `experimental.turbo`, `next lint`). These produce code that fails to compile or is deprecated. Verify against bundled docs.
- **Blanket "minimize 'use client'" with no guidance on where the boundary goes.** The agent either over-clientizes or breaks interactivity. Say "leaf components only" and give an example.
- **Duplicated style guide** that ESLint/Prettier already enforce. It wastes context. Delete it and tell the agent to run `pnpm lint --fix`.
- **Contradictory rules across files** (one says default exports, another says named). The model picks one at random. Grep your rules for conflicts.
- **Secrets or internal hostnames in rules.** They are committed and sent to the model provider. Reference env var *names* only.

## Accessibility
Encode the a11y rules the agent most often breaks. Semantic elements over ARIA (WCAG 4.1.2). Labels on every input (1.3.1, 3.3.2). Visible focus with `focus-visible:` (2.4.7, 2.4.11). Target size at least 24px (2.5.8). Colour never the sole cue (1.4.1). `prefers-reduced-motion` (2.3.3). Require an axe check in e2e for new pages and keyboard-only verification of dialogs and menus. Prefer shadcn/Radix primitives over hand-rolled widgets.

## Responsive Design
State the breakpoint strategy once (mobile-first Tailwind, container queries via `@container` for reusable cards). Require the agent to verify at 375px, 768px and 1440px when a UI change is visual. Give a rule to avoid fixed heights on text containers and to handle long content (truncate/line-clamp with a title or tooltip).

## Performance
Put the high-impact items from Vercel's react-best-practices into rules: no request waterfalls (`Promise.all` independent awaits, Suspense streaming), no barrel imports, `next/dynamic` for heavy client-only widgets, minimal props across the RSC boundary, and virtualization for long lists. Keep perf rules glob-scoped to `app/**` and `components/**`.

## Security
- Rules must never contain secrets. Treat `.cursor/rules` as public.
- Add a hard ban: never read, print or edit `.env*`, and never prefix a secret with `NEXT_PUBLIC_`.
- Require auth and input validation inside every Server Action and Route Handler.
- Community rule files and MCP configs are untrusted input. Review them for hidden instructions (e.g. "also run curl …" or zero-width characters) before committing.
- Cursor's agent can run terminal commands. Keep auto-run allowlists narrow and never allow network-writing or deploy commands.

## Testing
Test rules empirically. Keep 3–5 benchmark prompts ("add a /settings route with a form that saves via server action"), run them before and after rule changes, and diff outcomes: compile success, lint errors, number of `'use client'` files, token usage, a11y violations. Confirm attachment by opening a matching file and checking the rules listed in context.

## Tooling
- Cursor project rules (`.mdc`), `/create-rule`, User Rules, Team Rules (Team/Enterprise). Active.
- `AGENTS.md`, read by Cursor. Active and cross-tool.
- Legacy `.cursorrules`. Deprecated; migrate.
- PatrickJS/awesome-cursorrules (large, community). Mixed quality, many rules pinned to Next 14 with persona fluff. Mine for ideas only.
- cursor.directory (user-submitted rules + MCP listings). Unmoderated quality; same caveats.
- ESLint (flat config), Prettier, `tsc --noEmit`. These are the enforcement layer rules should delegate to.

## Framework Notes
- **Next.js App Router:** since 16.3, `next dev` auto-writes a managed block in `AGENTS.md` directing agents to `node_modules/next/dist/docs/`. Keep your rules outside that block and don't duplicate framework API explanations. Scope App Router rules to `app/**`.
- **React (Vite SPA):** replace the App Router rule with a routing/data rule (React Router or TanStack Router, TanStack Query for server state). Env vars are `import.meta.env.VITE_*` and all of them are public. There are no Server Components, so drop the `'use client'` guidance.

## AI Agent Guidance
- Do: read `AGENTS.md` and attached rules before editing. Follow canonical `@file` examples. Run typecheck/lint/test before declaring done.
- Do: when a rule conflicts with the bundled Next.js docs for the installed version, follow the docs and flag the stale rule to the user.
- Don't: add `'use client'` to route files, invent tokens, create barrel files, or edit `.env*`.
- When asked to write rules: produce scoped `.mdc` files under 80 lines, a trigger-style `description`, correct globs, no persona text, no secrets.
- Before done: the rule file parses (frontmatter first line `---`), globs match real paths, there are no contradictions with existing rules, and the benchmark task passes.

## Examples

Agent-requested workflow rule:
```mdc
---
description: Use when adding a new data-backed page or route segment in app/
alwaysApply: false
---
1. List routes (next-devtools MCP `get_routes` if configured, otherwise read app/) to find the parent layout.
2. Create page.tsx (Server Component), loading.tsx, error.tsx ('use client').
3. Put queries in lib/data/<entity>.ts with 'server-only' and cacheTag.
4. Mutations in actions.ts: zod-validate, auth check, revalidateTag.
5. Verify: pnpm typecheck && pnpm lint; open the route in the browser; check console is clean.
```

Minimal `AGENTS.md` companion (cross-tool):
```md
# Project
Next.js 16 App Router · React 19 · TS strict · Tailwind v4 · shadcn/ui · pnpm
## Commands
pnpm dev | pnpm typecheck | pnpm lint | pnpm test | pnpm test:e2e | pnpm build
## Structure
app/ routes · components/ui shadcn · components/<feature> · lib/data server-only queries
## Never
edit .env* · add deps without asking · use NEXT_PUBLIC_ for secrets · disable lint rules inline
```

## Related Skills
- [agents-md-conventions](../agents-md-conventions/Skill.md) — cross-tool source of truth that Cursor also reads
- [github-copilot-custom-instructions](../github-copilot-custom-instructions/Skill.md) — equivalent scoping with applyTo globs
- [other-coding-agents-frontend-rules](../other-coding-agents-frontend-rules/Skill.md) — Windsurf/Cline/Roo/Gemini/Aider equivalents
- [nextjs-agent-rules-baseline](../nextjs-agent-rules-baseline/Skill.md) — distilled Next.js rule content to paste into any tool
- [coding-agent-security-for-frontend](../coding-agent-security-for-frontend/Skill.md) — secrets, prompt injection, command allowlists
- [frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md) — the done criteria rules should point to
- [linting-and-formatting](../linting-and-formatting/Skill.md) — enforce mechanically instead of via rules
- [nextjs-app-router-fundamentals](../nextjs-app-router-fundamentals/Skill.md) — the conventions the rules encode

## Sources
- [Cursor Docs — Rules](https://cursor.com/docs/context/rules) — Official — .mdc format, frontmatter, rule types, 500-line guidance, User/Team rules, AGENTS.md
- [AGENTS.md](https://agents.md/) — Open spec — nearest-file precedence, sections
- [Next.js — AI agents guide](https://nextjs.org/docs/app/guides/ai-agents) — Official — managed AGENTS.md block, bundled docs
- [vercel-labs/agent-skills react-best-practices](https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/react-best-practices/SKILL.md) — Open Source (MIT) — perf rule categories
- [vercel-labs/agent-skills composition-patterns](https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/composition-patterns/SKILL.md) — Open Source (MIT) — composition rules
- [github/awesome-copilot nextjs.instructions.md](https://raw.githubusercontent.com/github/awesome-copilot/main/instructions/nextjs.instructions.md) — Community — current Next 16 conventions cross-check
- [PatrickJS/awesome-cursorrules](https://github.com/PatrickJS/awesome-cursorrules) — Community — surveyed; many Next 14-era rules, used only as a negative example
- [Claude Code best practices](https://code.claude.com/docs/en/best-practices) — Official — include/exclude guidance for instruction files

## License / Usage Notes
Content is summarized and rewritten. Example rules are original, informed by the sources above. Vercel agent-skills is MIT. awesome-cursorrules is CC0-style community content, but individual rule quality varies, so none is copied. Cursor docs are proprietary documentation, paraphrased.

## Quality Tier
A — built on official Cursor docs plus current Next.js docs with tested-pattern rule examples. Not S because Cursor's rule semantics change often and attachment behaviour was not verified in a live Cursor session.

## Status
Active

## Last Verified
2026-09-15
