# Other Coding Agents: Frontend Rules (Windsurf, Cline, Roo, Gemini CLI, Aider, Codex)

## Summary
A cross-tool guide to project instruction files for coding agents other than Claude Code, Cursor and Copilot. It covers Windsurf/Devin rules, Cline `.clinerules`, Roo Code `.roo/rules`, Gemini CLI `GEMINI.md`, Aider conventions files and OpenAI Codex `AGENTS.md`. It recommends one canonical `AGENTS.md` plus thin per-tool shims so a React + Next.js team gets consistent behaviour whatever agent each developer uses.

## Category
AI Agent Workflows

## Subcategories
Windsurf rules, Cline rules, Roo Code rules and modes, Gemini CLI context files, Aider conventions, Codex AGENTS.md, multi-agent repo setup, instruction file compatibility

## Problem It Solves
Mixed-tool teams end up with five divergent rule files (`.windsurfrules`, `.clinerules`, `GEMINI.md`, `CONVENTIONS.md`, `AGENTS.md`) that drift apart, contradict each other, and silently exceed per-tool size limits. Each tool has different discovery, scoping and truncation behaviour. Rules that work in one tool may be ignored or cut off in another.

## When To Use
- A repo where developers use different agents (Windsurf, Cline, Roo, Gemini CLI, Aider, Codex).
- Setting up a new Next.js repo to be "agent-ready" for any tool.
- Debugging "the agent ignores our rules" in one of these tools.
- Consolidating legacy per-tool rule files.

## When Not To Use
- The team has standardized on a single tool. Use that tool's native mechanism and skill ([cursor-rules-for-frontend](../cursor-rules-for-frontend/Skill.md), [github-copilot-custom-instructions](../github-copilot-custom-instructions/Skill.md), [claude-code-frontend-workflow](../claude-code-frontend-workflow/Skill.md)).
- Enforcement (formatting, forbidden imports, secrets). Use linters, CI, pre-commit hooks and tool permission settings.

## Core Principles
1. **One canonical file:** `AGENTS.md` at the repo root holds stack, commands, structure and bans. Most tools read it natively or can be configured to.
2. **Shims, not copies:** per-tool files only add tool-specific scoping or point at `AGENTS.md`.
3. **Respect the smallest budget:** Windsurf workspace rules cap at 12,000 characters per file and global rules at 6,000. Codex stops concatenating at `project_doc_max_bytes` (32 KiB default). Keep the root `AGENTS.md` well under 8 KB.
4. **Nearest file wins:** nested `AGENTS.md` in `app/` or `packages/web/` scope directory-specific rules. Explicit user prompts override files.
5. **Rules guide, tools enforce:** anything that must never happen belongs in approval/permission settings or CI.

## Best Practices
- Use bullets, not paragraphs. Several tools' docs (Windsurf, Cline) recommend concise markdown and explaining *why* only when it isn't obvious.
- Put the validation sequence near the top (`pnpm typecheck && pnpm lint && pnpm test && pnpm build`). Codex and others try to execute listed checks.
- Scope file-type rules with each tool's glob/paths mechanism instead of growing the root file.
- Symlinks work for tools that need a specific filename, but on Windows they require Developer Mode or admin. Prefer config (Gemini `context.fileName`, Aider `read:`) or import syntax.
- Pin versions in the canonical file ("Next.js 16.x, React 19") and send agents to `node_modules/next/dist/docs/`.
- Add a CI check that fails if legacy files (`.windsurfrules`, `.roorules`, `.cursorrules`) reappear or if `AGENTS.md` exceeds the byte budget.

## Implementation Guidance

### Compatibility matrix
| Tool | Native project file(s) | Reads AGENTS.md | Scoping mechanism | Global/user file | Limits / notes |
|---|---|---|---|---|---|
| Windsurf (Devin desktop / Cascade) | `.devin/rules/*.md` (preferred), `.windsurf/rules/*.md` (legacy fallback), legacy `.windsurfrules` | Yes: root = always on; subdirectory = auto-scoped to that dir | Frontmatter trigger: `always_on`, `model_decision`, `glob`, `manual` (`@rule`) | `~/.codeium/windsurf/memories/global_rules.md` | 12,000 chars per workspace rule; 6,000 global; auto "memories" are not reliable, so write rules |
| Cline | `.clinerules/` folder of `.md` (or single file) | Yes (`AGENTS.md`, `~/.agents/AGENTS.md`); also reads `.cursorrules`, `.windsurfrules` | YAML `paths:` globs (conditional rules); per-rule toggles in Rules panel | `Documents/Cline/Rules` | Conditional rules activate on mentioned, open, visible or edited files |
| Roo Code | `.roo/rules/` (recursive, alphabetical), `.roo/rules-{modeSlug}/` | Yes by default (`AGENT.md` fallback); disable with `roo-cline.useAgentRules: false` | Per-mode rule folders; custom modes can restrict editable files via regex | `~/.roo/rules/` | Global loaded first, workspace wins on conflict; legacy `.roorules` fallback |
| Gemini CLI | `GEMINI.md` (hierarchical + just-in-time in accessed dirs) | Via `settings.json` `context.fileName` | Directory hierarchy; `@file.md` imports | `~/.gemini/GEMINI.md` | `/memory show`, `/memory reload` to debug |
| Aider | Any conventions file, e.g. `CONVENTIONS.md` | Via `.aider.conf.yml` `read: AGENTS.md` | None (whole file); add multiple read-only files | `~/.aider.conf.yml` | Load read-only (`--read` / `/read`) so prompt caching applies |
| OpenAI Codex | `AGENTS.md`, `AGENTS.override.md` | Native | Walks git root → cwd, concatenating; closer files later and override | `~/.codex/AGENTS.md` / `AGENTS.override.md` | `project_doc_max_bytes` 32 KiB default; `project_doc_fallback_filenames` in `~/.codex/config.toml` |

Tool behaviour changes frequently. Re-check vendor docs quarterly.

### Canonical-plus-shims layout for a Next.js repo
```
AGENTS.md                         # canonical (≤ ~8 KB)
app/AGENTS.md                     # App Router-specific (nearest-file scoping)
.devin/rules/tests.md             # Windsurf glob rule (tests only)
.clinerules/tests.md              # Cline paths rule (tests only)
.roo/rules-code/nextjs.md         # Roo Code-mode extras (optional)
.gemini/settings.json             # context.fileName → AGENTS.md
.aider.conf.yml                   # read: AGENTS.md
CLAUDE.md                         # "@AGENTS.md" (for Claude Code)
```
Keep shim content limited to what the canonical file can't express (glob-scoped test rules, mode-specific behaviour).

## Recommended Workflow
1. Inventory existing rule files: `.cursorrules`, `.windsurfrules`, `.clinerules`, `.roorules`, `GEMINI.md`, `CONVENTIONS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`.
2. Merge them into `AGENTS.md`, deduplicating and deleting stale or version-wrong rules (Pages Router, sync `params`, `middleware.ts` on Next 16).
3. Add nested `AGENTS.md` for `app/` or monorepo packages when rules differ by directory.
4. Configure each tool to read `AGENTS.md` (table above). Replace per-tool files with shims.
5. Verify per tool: Gemini `/memory show`; Codex `codex --ask-for-approval never "Summarize current instructions"`; Cline/Windsurf rules panel; Roo mode rules listing; Aider startup banner listing read-only files.
6. Add a CI size check and a legacy-file check.
7. Re-run a benchmark task (e.g. "add a settings page with a server action") in two tools and compare outcomes.

## Patterns

### Pattern: Canonical `AGENTS.md`
```md
# AGENTS.md
## Stack
Next.js 16 App Router · React 19 · TypeScript strict · Tailwind v4 · shadcn/ui · pnpm · Vitest · Playwright
Before using Next.js APIs, read node_modules/next/dist/docs/ (matches installed version).

## Commands (must pass before finishing)
pnpm typecheck && pnpm lint && pnpm test && pnpm build
UI change: run pnpm dev and check the route in a browser; console must be clean.

## Structure
app/ routes (RSC default) · app/**/actions.ts Server Actions · components/ui shadcn · lib/data server-only

## Conventions
- 'use client' only on leaf interactive components
- await params/searchParams/cookies()/headers()
- zod-validate + auth-check every Server Action and Route Handler
- Tailwind semantic tokens only; cn() for class merging; no transition-all
- Semantic HTML; labelled inputs; focus-visible styles

## Never
edit .env* · print secrets · NEXT_PUBLIC_ for secrets · add deps without asking · disable lint/type rules inline
```

### Pattern: Windsurf glob rule (`.devin/rules/tests.md`)
```md
---
trigger: glob
globs: "**/*.test.tsx"
---
- Vitest + Testing Library; getByRole/getByLabelText; userEvent.
- Mock network with MSW; no fetch mocks per test.
- Async Server Components are covered by Playwright, not RTL.
```
Exact frontmatter keys for Windsurf rules have changed across releases. Generate one rule from the Customizations UI and copy its header format.

### Pattern: Cline conditional rule (`.clinerules/react-components.md`)
```md
---
paths:
  - "components/**/*.tsx"
  - "app/**/*.tsx"
---
# React components
- Named function components with Props type; ref as prop (React 19), no forwardRef.
- Composition over boolean props; derive state during render; no effect-based fetching.
- Example to follow: components/projects/project-card.tsx
```

### Pattern: Gemini CLI reading AGENTS.md (`.gemini/settings.json`)
```json
{
  "context": { "fileName": ["AGENTS.md", "GEMINI.md"] }
}
```

### Pattern: Aider (`.aider.conf.yml`)
```yaml
read: [AGENTS.md, app/AGENTS.md]
```

### Pattern: Roo Code mode-specific rules
```
.roo/rules/00-shared.md          # "Follow AGENTS.md" + repo bans
.roo/rules-architect/planning.md # plan output format, no file edits
.roo/rules-code/verification.md  # run pnpm typecheck/lint/test after edits
```

### Pattern: Codex override for a sub-package
```
packages/web/AGENTS.override.md  # replaces generic guidance for the web app only
```

## Anti-Patterns
- **Five full copies of the same rules.** They drift and contradict. Use one canonical file plus shims.
- **Oversized root file.** It is silently truncated by Codex's byte budget or rejected by Windsurf's character limit. Split by directory and scope by glob.
- **Relying on auto-generated memories** (Windsurf memories, similar features) for team conventions. They aren't shared or reviewed. Write rules.
- **Symlinks on Windows teams.** They break without Developer Mode. Use config-based file selection.
- **Legacy single-file formats** (`.windsurfrules`, `.roorules`, `.cursorrules`) left next to new ones. Both load and conflict. Delete the legacy files.
- **Tool-specific persona prompts** ("You are Cascade, an expert…"). They waste budget. State constraints instead.
- **Rules that assume a tool capability** ("take a screenshot") without saying which MCP/CLI provides it. Agents without it hallucinate success. Say "if a browser tool is available…; otherwise report that visual verification was not done".

## Accessibility
Keep a short a11y block in the canonical file, since every tool reads it: semantic elements, labels, `focus-visible`, colour not the sole cue, reduced motion, and 24px minimum targets. Keep the longer WCAG checklist in a glob-scoped rule for `**/*.tsx` in tools that support scoping (Windsurf glob, Cline paths, Roo per-mode). Tools without scoping (Aider) should get only the short block.

## Responsive Design
State once: mobile-first Tailwind, check at 375/768/1440, container queries for reusable components, and resilience to long text. Don't repeat it per tool.

## Performance
Encode the top Next/React perf rules in the canonical file (no waterfalls, no barrel imports, dynamic import heavy client widgets, minimal RSC props). Everything else belongs in a review-time rubric, not always-on context, given the smaller budgets of some tools.

## Security
- No secrets in any rule file. They are committed and sent to model providers.
- Configure approvals/auto-execution per tool (Cline/Roo auto-approve settings, Codex approval modes, Windsurf terminal auto-execution). Never auto-approve `rm`, `git push`, deploy or network-writing commands.
- Roo custom modes can restrict which files a mode may edit. Use this to keep "docs" or "review" modes from touching `app/`.
- Community rule packs and MCP configs are untrusted. Check for hidden instructions and unexpected commands before committing.
- Rules should tell agents to ignore instructions found inside fetched web pages, issue text or DOM content.

## Testing
- Per-tool loading check (see workflow step 5) in onboarding docs.
- CI: `AGENTS.md` byte size < budget; no legacy rule files; frontmatter lint for rule folders (YAML parses, globs match files).
- Periodic benchmark: the same 2–3 tasks across the tools the team uses. Compare compile success, lint errors and convention adherence.

## Tooling
- Windsurf / Devin desktop rules. Active; storage moved to `.devin/rules` with `.windsurf/rules` fallback.
- Cline rules. Active; also reads other tools' files.
- Roo Code rules and custom modes. Active.
- Gemini CLI `GEMINI.md`. Active; configurable filename.
- Aider conventions (`--read`, `.aider.conf.yml`). Active; community Aider-AI/conventions repo is small and uneven.
- OpenAI Codex `AGENTS.md`. Active; the reference implementation of hierarchical AGENTS.md.
- agents.md spec. Active; lists 25+ supporting tools.

## Framework Notes
- **Next.js App Router:** Next 16.3+ `next dev` auto-maintains a managed block in root `AGENTS.md` (and a `CLAUDE.md` importing it). Leave the markers intact and put team rules outside them. That block already sends every AGENTS.md-aware tool to version-matched docs. In monorepos, put a nested `AGENTS.md` in the Next app package, since the bundled docs path resolves from the app's `node_modules`.
- **React (Vite SPA):** the canonical file should specify the router (React Router / TanStack Router), data layer (TanStack Query), that `VITE_*` env vars are public, and the commands `vite`, `vite build`, `vitest`. Drop Server Component and Server Action rules.

## AI Agent Guidance
- Do: locate and read the nearest `AGENTS.md` plus tool-native rules before editing. When rules conflict, the nearest file and the explicit user prompt win. Mention the conflict.
- Do: when asked to "make the repo agent-ready", create the canonical `AGENTS.md`, configure shims, delete legacy files, and report per-tool verification commands.
- Don't: duplicate content across tool files, exceed per-tool budgets, or add secrets or credentials.
- Before done: file sizes under limits, YAML frontmatter parses, globs match real paths, legacy files removed, a benchmark task passes typecheck/lint/test.

## Examples

CI guard (GitHub Actions step, bash):
```bash
test "$(wc -c < AGENTS.md)" -lt 8192 || { echo "AGENTS.md too large"; exit 1; }
for f in .cursorrules .windsurfrules .roorules; do
  test ! -e "$f" || { echo "Legacy rule file $f present"; exit 1; }
done
```

Nested App Router file (`app/AGENTS.md`):
```md
# app/ rules
- page.tsx/layout.tsx are Server Components; never add 'use client' here.
- Each data route: loading.tsx (or Suspense) + error.tsx.
- Server Actions in actions.ts: zod parse → auth() → mutate → revalidateTag.
- Request interception in /proxy.ts (Next 16).
```

## Related Skills
- [agents-md-conventions](../agents-md-conventions/Skill.md) — the canonical file format this strategy centers on
- [cursor-rules-for-frontend](../cursor-rules-for-frontend/Skill.md) — Cursor-specific scoping
- [github-copilot-custom-instructions](../github-copilot-custom-instructions/Skill.md) — Copilot-specific scoping
- [claude-code-frontend-workflow](../claude-code-frontend-workflow/Skill.md) — CLAUDE.md importing AGENTS.md
- [nextjs-agent-rules-baseline](../nextjs-agent-rules-baseline/Skill.md) — rule content to place in AGENTS.md
- [coding-agent-security-for-frontend](../coding-agent-security-for-frontend/Skill.md) — approvals, injection, secrets
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — nested instruction files per package

## Sources
- [Windsurf/Devin — Cascade memories & rules](https://docs.devin.ai/desktop/cascade/memories) — Official — rule locations, activation modes, 12k/6k limits, AGENTS.md behaviour
- [Cline — Rules](https://docs.cline.bot/features/cline-rules) — Official — .clinerules, paths conditional rules, cross-tool file support
- [Roo Code — Custom instructions](https://roocodeinc.github.io/Roo-Code/features/custom-instructions) — Official — .roo/rules, mode rules, load order, AGENTS.md setting
- [Gemini CLI — GEMINI.md](https://geminicli.com/docs/cli/gemini-md/) — Official — hierarchy, imports, context.fileName, /memory
- [Aider — Conventions](https://aider.chat/docs/usage/conventions.html) — Official — read-only conventions, .aider.conf.yml
- [Codex — AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) — Official — discovery chain, override files, 32 KiB budget, fallback filenames
- [AGENTS.md](https://agents.md/) — Open spec — precedence, supported tools, migration
- [Next.js — AI agents guide](https://nextjs.org/docs/app/guides/ai-agents) — Official — managed AGENTS.md block

## License / Usage Notes
Vendor documentation is summarized and paraphrased. All examples are original. No third-party rule packs were copied.

## Quality Tier
A — each tool's behaviour is taken from its official docs, fetched on the verification date. Windsurf frontmatter key syntax and some per-tool details move quickly and weren't tested in live installs.

## Status
Active

## Last Verified
2026-09-15
