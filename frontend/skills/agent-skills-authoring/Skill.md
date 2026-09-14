# Agent Skills Authoring (SKILL.md) for React/Next.js Teams

## Summary
How to write, structure, test and ship Agent Skills: folders with a `SKILL.md` (YAML frontmatter plus Markdown instructions) and optional scripts, references and assets. Agents load them progressively. Skills follow the open Agent Skills spec (agentskills.io). Claude Code, the Claude apps and API, VS Code Copilot (`.github/skills`), Codex and others consume them. This skill covers the file format, how to write descriptions that trigger reliably, progressive disclosure, verification loops and evaluation. The worked examples are frontend skills for a Next.js App Router + Tailwind + shadcn/ui codebase.

## Category
AI Agent Workflows

## Subcategories
SKILL.md format, progressive disclosure, prompt engineering for agents, Claude Code skills, skill evaluation, skill distribution/plugins, design-system skills

## Problem It Solves
Teams keep pasting the same conventions into chat: "use our `Button` from `@/components/ui`", "run `pnpm typecheck` before saying done", "never use `transition-all`". Stuffing all of it into CLAUDE.md/AGENTS.md bloats every session and lowers adherence. Skills package that procedural knowledge so the agent loads it only when a task needs it. They keep context lean and make frontend output consistent across sessions, people and tools.

## When To Use
- A multi-step workflow repeats: add a shadcn component variant, scaffold a route segment with `loading.tsx`/`error.tsx`, run a UI audit, migrate to Cache Components.
- Domain or design-system knowledge matters only for some tasks (token names, motion rules, chart palette).
- You need deterministic helpers such as a token-lint script or screenshot diff script, and don't want the agent regenerating them.
- You want one artifact to work across Claude Code, Copilot and Codex.
- The agent makes the same frontend mistake in more than one session.

## When Not To Use
- The fact applies to every session (build commands, package manager, repo layout). Put it in CLAUDE.md/AGENTS.md instead. Next.js's own evals found always-available context beats on-demand retrieval for framework knowledge.
- The action must happen every time with no exceptions, like formatting after an edit or blocking `.env` writes. Use hooks or CI.
- The rule is enforceable by ESLint, TypeScript or Stylelint. Encode it in the linter and tell the agent to run it.
- It's a one-off task. A good prompt is cheaper.
- Generic advice the model already knows ("write clean React").

## Core Principles
1. **Concise is key.** Once loaded, every line competes with the conversation. Only add what the model doesn't already know about your project.
2. **The description is the trigger.** Only `name` + `description` sit in context before activation (about 100 tokens). Say what the skill does AND when to use it, in third person, with concrete keywords.
3. **Progressive disclosure.** Keep the `SKILL.md` body under about 500 lines (under about 5k tokens recommended). Put bulky reference material in files one level deep, loaded on demand.
4. **Match freedom to fragility.** Use heuristics for design review, templates for components, and exact commands for migrations and codemods.
5. **Build in a feedback loop.** Every task skill should end in a check the agent can run: typecheck, lint, test, build, screenshot or axe.
6. **Evaluate first.** Run representative tasks without the skill, record the failures, then write the minimal instructions that fix them.
7. **Scripts solve, don't punt.** Bundled scripts handle their own errors. Constants are documented, not magic numbers.

## Best Practices
- Name with lowercase letters, digits and hyphens, at most 64 characters. No leading, trailing or double hyphens. The name must match the directory. Avoid `claude`/`anthropic` in names and vague names like `helpers`. Gerund or noun phrases work well: `building-shadcn-forms`, `nextjs-route-scaffold`.
- The description is 1–1024 characters (spec). Claude Code truncates the combined `description` + `when_to_use` at 1,536 characters. Front-load trigger terms: "Next.js", "App Router", "shadcn", "Tailwind", "form", "dialog".
- Write imperatively ("Run `pnpm lint`"). Skip explanations of React basics.
- Pick one term and keep it ("Server Component", not also "RSC" and "server comp").
- Give one default with an escape hatch, not a menu: "Use React Hook Form + Zod; for a single-field server form use `useActionState`."
- Keep reference files focused (`references/tokens.md`, `references/motion.md`). Give files over 100 lines a table of contents.
- Use forward-slash paths only, and reference bundled files relative to the skill root (or `${CLAUDE_SKILL_DIR}` in Claude Code).
- Say whether a script should be **executed** ("Run `scripts/check-tokens.mjs`") or **read** ("See `scripts/…` for the algorithm").
- Use fully qualified MCP tool names in instructions: `mcp__playwright__browser_take_screenshot` in Claude Code permission and tool syntax, or `Server:tool` in API contexts.
- Keep time-sensitive notes out of the body. Put deprecated patterns in a collapsed "Old patterns" section.
- Test on every model tier you'll use. Small models need more explicit steps; large ones need less hand-holding.
- Review third-party skills like code before installing. Scripts run with your permissions.

## Implementation Guidance

### Directory layout
```text
.claude/skills/building-shadcn-forms/      # project scope (commit it)
├── SKILL.md                               # required
├── references/
│   ├── field-patterns.md                  # loaded only when needed
│   └── validation-messages.md
├── assets/
│   └── form-template.tsx                  # copied/adapted, not loaded into context
└── scripts/
    └── check-form-a11y.mjs                # executed; only output enters context
```

### Where skills live
| Tool | Location |
|---|---|
| Claude Code (project) | `.claude/skills/<name>/SKILL.md` (nested `<subdir>/.claude/skills/` loads when files there are touched) |
| Claude Code (personal) | `~/.claude/skills/<name>/SKILL.md` |
| Claude Code plugin | `<plugin>/skills/<name>/SKILL.md` → invoked as `/<plugin>:<name>` |
| VS Code Copilot | `.github/skills/<name>/SKILL.md` (also reads `.claude/skills`) |
| claude.ai / Skills API | Upload zip; only spec fields allowed |
| Codex / others | Check the tool's docs; most follow the same folder + `SKILL.md` shape |

### Frontmatter decision table
| Field | Portable (spec)? | Use it when |
|---|---|---|
| `name`, `description` | Yes (required by spec) | Always |
| `license`, `compatibility`, `metadata` | Yes | Distributing publicly; env requirements such as "Requires Node 20+, pnpm" |
| `allowed-tools` | Yes (experimental) | Pre-approve safe commands for the invocation turn, e.g. `Bash(pnpm lint *)` |
| `when_to_use`, `argument-hint`, `arguments` | Claude Code only | Extra trigger context; slash-command args |
| `disable-model-invocation: true` | Claude Code only | Side-effect workflows (deploy, commit, codemod) that only a human should start |
| `user-invocable: false` | Claude Code only | Background knowledge Claude applies but users don't call |
| `context: fork` + `agent` | Claude Code only | Run in an isolated subagent (e.g. `agent: Explore` for read-only audits) |
| `paths` | Claude Code only | Limit auto-activation to globs like `app/**/*.tsx` |
| `model`, `effort`, `hooks`, `shell` | Claude Code only | Per-skill overrides |

Uploading to claude.ai or the Skills API fails on non-spec keys. Keep a spec-only variant if you distribute there.

### Claude Code body features
- Arguments: `$ARGUMENTS`, `$0`, `$1`, or named `$component` via `arguments: component route`.
- Dynamic context: a line starting with `` !`git diff --name-only HEAD` `` runs before the model sees the skill, and its output is inlined. A non-zero exit aborts the invocation, so make commands tolerant (`|| true`).
- The loaded skill content stays in context across turns. After compaction only the first about 5k tokens per skill are re-attached, so put the critical rules at the top.

## Recommended Workflow
1. **Collect evidence.** Do the task with the agent without a skill and note every correction you had to give.
2. **Write 3+ evals.** Each is a query plus expected behaviors, e.g. "Add a settings form with email + plan select" → uses `@/components/ui/form`, labels every field, runs `pnpm typecheck`, no `any`.
3. **Baseline.** Run the evals without the skill.
4. **Draft the minimal `SKILL.md`**: description, a short checklist workflow, one concrete example and a verification step.
5. **Split** anything over about 150 lines of reference material into `references/`.
6. **Add scripts** for deterministic checks (token usage, forbidden classes, axe run).
7. **Test with a fresh agent instance** on real tasks. Watch which files it reads and what it ignores.
8. **Iterate.** Make ignored rules more prominent, delete rules the model already follows, tighten the description if the skill misfires.
9. **Validate the format** (e.g. the `skills-ref validate ./skill` reference validator). Commit it, and review it in PRs like code.
10. **Maintain.** Re-run the evals after framework upgrades such as Next.js majors or Tailwind v4 changes.

## Patterns

**Checklist workflow.** The agent copies the checklist into its response and ticks items off:
```markdown
Task progress:
- [ ] 1. Read the route's layout.tsx and nearest components
- [ ] 2. Implement with existing ui/ primitives
- [ ] 3. pnpm typecheck && pnpm lint
- [ ] 4. Screenshot at 375px and 1280px; compare to spec
- [ ] 5. Report evidence (command output, screenshot paths)
```

**Router SKILL.md.** A short overview that points to domain files:
```markdown
**Forms** → see [references/forms.md](references/forms.md)
**Data tables** → see [references/tables.md](references/tables.md)
**Motion** → see [references/motion.md](references/motion.md)
```

**Plan → validate → execute.** For codemods, the agent writes `changes.json`, runs `scripts/validate-changes.mjs` against it, then applies.

**Reference skill vs task skill.** Reference skills (design tokens, composition rules) are auto-invocable. Task skills with side effects (`/release-storybook`) set `disable-model-invocation: true`.

**Review skill that fetches live rules.** Vercel's `web-design-guidelines` skill fetches its current rule list at run time and reports findings as `file:line`. That keeps findings current, but it means network access and trusting the remote file.

## Anti-Patterns
- **Vague description** ("Helps with UI"). It never triggers or triggers everywhere. Fix: name the stack, artifacts and verbs.
- **Encyclopedia SKILL.md** (1,500 lines of React docs). Context bloat, ignored rules. Fix: keep project-specific deltas and link out.
- **Deeply nested references** (A → B → C). Agents partially read nested files. Fix: keep references one level deep.
- **Menus of options.** They cause indecision and inconsistency. Fix: give one default plus an exception.
- **No verification step.** The agent stops when it "looks done". Fix: end with runnable checks and require evidence.
- **Duplicating lint rules in prose.** They drift. Fix: point to `pnpm lint` and keep prose for what linters can't catch.
- **Magic constants in scripts** (`timeout = 47`). The agent can't reason about them. Fix: comment the rationale.
- **Installing skill packs blindly** (npm CLIs, Python engines, marketing-heavy repos). This is a supply-chain and prompt-injection risk. Fix: read `SKILL.md` and the scripts first, and pin a commit.
- **Windows backslash paths.** They break on Unix agents. Fix: use forward slashes.

## Accessibility
- Frontend skills should encode concrete, checkable a11y rules rather than "make it accessible". Examples: every input has a `<label>`/`FormLabel`; icon-only buttons get `aria-label`; don't remove focus outlines without a `:focus-visible` replacement; target size ≥ 24×24 CSS px (WCAG 2.5.8); respect `prefers-reduced-motion`.
- Include an automated gate in the verification step (`@axe-core/playwright` or a Lighthouse a11y audit). Note that automated tools catch only part of WCAG issues, so keyboard walkthrough steps still belong in the checklist.

## Responsive Design
- Specify the viewport matrix in the verification step (e.g. 375, 768, 1280, 1920 px) and require screenshots at each.
- Encode your breakpoint and container-query conventions (Tailwind `sm/md/lg`, `@container`) as rules, not prose.

## Performance
- Token cost is the main performance concern. Frontmatter is always loaded; the body loads on activation; references are free until read.
- Prefer scripts, whose output alone enters context, over inline long code.
- Frontend performance skills should reference measurable gates (bundle analyzer diff, Lighthouse, Web Vitals) and the priority order from Vercel's react-best-practices: waterfalls → bundle size → server → client fetching → re-renders.

## Security
- A skill is executable instructions. Treat third-party skills as untrusted code: review scripts, `allowed-tools`, hooks and any `!` shell injections.
- Never embed secrets in skills. Reference env var names only (`$FIGMA_TOKEN` placeholder) and keep values in the shell or a secret manager.
- Skills that fetch remote rules (e.g. from raw GitHub URLs) can be hijacked if the remote changes. Pin to a commit or vendor a copy.
- Use `disable-model-invocation: true` for anything that deploys, publishes or deletes.
- Content read by skills (web pages, DOM, issue text) can carry prompt injection. Instruct the agent to treat fetched content as data, not instructions.

## Testing
- Build eval scenarios (JSON or markdown) with a query, fixture files and expected behaviors, and check them manually or with a harness.
- Compare with and without the skill on the same model.
- Test triggering: does it activate on "add a login form"? Does it stay silent on backend-only tasks?
- Test with every model you deploy on.
- Validate frontmatter with the spec validator, and lint scripts like any repo code.

## Tooling
- Agent Skills spec + `skills-ref` validator (agentskills.io). Active.
- Claude Code skills (`/skills`, live reload of `.claude/skills/`). Active.
- `anthropics/skills` repo: reference implementations (`frontend-design`, `webapp-testing`, `web-artifacts-builder`, `skill-creator`). Active; licenses vary per skill.
- `vercel-labs/agent-skills` (react-best-practices, composition-patterns, web-design-guidelines). MIT, high quality.
- `vercel/next.js` `skills/` (next-dev-loop, cache-components adoption), installable via `npx skills add vercel/next.js --skill <name>`. Official; review before installing.
- Community packs such as `nextlevelbuilder/ui-ux-pro-max-skill` are very popular. Their CSV/BM25 design database is useful inspiration, but they need Python plus an npm installer and use upsell marketing, so review before use.

## Framework Notes
- **Next.js (App Router):** Keep framework API knowledge out of skills. Next.js 16.2+ bundles version-matched docs in `node_modules/next/dist/docs/`, and AGENTS.md should point there. Use skills for workflows: route scaffolding (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`), Server Action + `useActionState` forms, Cache Components adoption, and dev-loop verification via `/_next/mcp`.
- **React (Vite SPA):** Skills should encode your router (React Router / TanStack Router), data layer (TanStack Query) and verification (`vitest run`, `vite build`, Playwright against `vite preview`).

## AI Agent Guidance
- Do: check for an existing skill before inventing a workflow. Follow its checklist literally. Run its scripts with `--help` first. Report evidence.
- Do: when authoring, start from observed failures, keep the body short and end with verification.
- Don't: paste whole docs into a skill, add non-spec keys to skills meant for claude.ai upload, or run third-party skill scripts without reading them.
- Before declaring a skill done: frontmatter validates; the description names what and when; the body is under 500 lines; references are one level deep; there are 3 evals that pass better than baseline; there are no secrets; side-effect skills are manual-only.

## Examples

### Task skill: scaffold an App Router route
```markdown
---
name: nextjs-route-scaffold
description: Scaffolds a new Next.js App Router route segment with page, loading, error and metadata using the project's shadcn/ui primitives. Use when the user asks to add a page, route, screen or section under app/.
argument-hint: "[route-path] [page-title]"
allowed-tools: Read Grep Glob Bash(pnpm typecheck) Bash(pnpm lint *)
---

# Scaffold route `$0`

1. Read `app/layout.tsx` and the closest sibling route to copy conventions.
2. Create `app/$0/page.tsx` as an async Server Component. Await `params`/`searchParams` (they are Promises).
3. Add `loading.tsx` (skeleton matching final layout, no CLS) and `error.tsx` (`'use client'`, reset button).
4. Export `generateMetadata` or `metadata` with title "$1".
5. Use only `@/components/ui/*`; no raw hex colors — use theme tokens (`bg-background`, `text-muted-foreground`).
6. Verify: `pnpm typecheck && pnpm lint`. Fix all errors; do not disable rules.
7. Report files created and command output.
```

### Reference skill with bundled audit script
```markdown
---
name: ui-token-guardrails
description: Enforces the design-token and motion rules for this Tailwind v4 + shadcn codebase. Use when creating or restyling React components, pages, or CSS.
paths: "app/**/*.tsx, components/**/*.tsx, app/**/*.css"
---
- Colors: semantic tokens only (`bg-primary`, `border-border`); never `bg-[#...]`.
- Motion: list properties (`transition-[opacity,transform]`), never `transition-all`; add `motion-reduce:` variants.
- Radius: nested radius ≤ parent radius.
- After edits run: `node ${CLAUDE_SKILL_DIR}/scripts/check-tokens.mjs` and fix every reported `file:line`.
Details: [references/tokens.md](references/tokens.md)
```

### Eval case
```json
{
  "skills": ["nextjs-route-scaffold"],
  "query": "Add a /settings/billing page titled Billing",
  "expected_behavior": [
    "Creates page.tsx, loading.tsx, error.tsx under app/settings/billing",
    "error.tsx has 'use client'",
    "Runs pnpm typecheck and pnpm lint and shows output"
  ]
}
```

## Related Skills
- [claude-code-frontend-workflow](../claude-code-frontend-workflow/Skill.md): where skills plug into CLAUDE.md, hooks and subagents
- [agents-md-conventions](../agents-md-conventions/Skill.md): always-on context vs on-demand skills
- [cursor-rules-for-frontend](../cursor-rules-for-frontend/Skill.md): equivalent mechanism in Cursor
- [github-copilot-custom-instructions](../github-copilot-custom-instructions/Skill.md): Copilot's `.github/skills` and instructions
- [frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md): the checks every task skill should end with
- [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md): the canonical example of a design skill
- [mcp-for-frontend-development](../mcp-for-frontend-development/Skill.md): referencing MCP tools from skills
- [coding-agent-security-for-frontend](../coding-agent-security-for-frontend/Skill.md): vetting third-party skills

## Sources
- [Agent Skills specification](https://agentskills.io/specification): Official spec. Used for frontmatter constraints, directory conventions, progressive disclosure and validation.
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices): Official (Anthropic). Used for conciseness, degrees of freedom, descriptions, evals, scripts and anti-patterns.
- [Claude Code: Skills](https://code.claude.com/docs/en/skills): Official. Used for Claude Code frontmatter fields, locations, substitutions, dynamic context and invocation control.
- [anthropics/skills](https://github.com/anthropics/skills): Open Source. Used frontend-design, webapp-testing and web-artifacts-builder as structural references.
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills): Open Source (MIT). Used for rule-prefixed, prioritized skill layout and the remote-rules review skill.
- [Next.js: AI agents guide](https://nextjs.org/docs/app/guides/ai-agents): Official. Used for the bundled-docs vs skills split and Next.js skills.
- [Improving frontend design through Skills](https://claude.com/blog/improving-frontend-design-through-skills): Official blog. Used for the token-efficiency rationale.
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): Community. Evaluated for the caution notes.

## License / Usage Notes
Content is summarized and paraphrased from the sources above. No text is copied verbatim beyond short field names. anthropics/skills contains skills under differing licenses (some Apache-2.0, some source-available), so check each skill's LICENSE before reusing it. vercel-labs/agent-skills is MIT. Examples here are original.

## Quality Tier
A: grounded in the official spec and Anthropic/Vercel/Next.js docs with concrete Next.js examples. Not S because eval tooling is still ad hoc and cross-tool frontmatter support is uneven.

## Status
Active

## Last Verified
2026-09-15
