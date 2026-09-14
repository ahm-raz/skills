# Manifest — W17 AI Coding-Agent Frontend Workflows

Scope: React + Next.js (TypeScript, App Router; Tailwind/shadcn defaults). Last verified 2026-09-15.
Extra slugs added (not in TAXONOMY.md): `nextjs-agent-rules-baseline`, `coding-agent-security-for-frontend`.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| agent-skills-authoring | Agent Skills Authoring (SKILL.md) for React/Next.js Teams | AI Agent Workflows | React, Next.js | A | Active | https://agentskills.io/specification |
| claude-code-frontend-workflow | Claude Code Frontend Workflow (Next.js App Router) | AI Agent Workflows | Next.js, React | A | Active | https://code.claude.com/docs/en/best-practices |
| cursor-rules-for-frontend | Cursor Rules for Frontend (React + Next.js) | AI Agent Workflows | Next.js, React | A | Active | https://cursor.com/docs/context/rules |
| agents-md-conventions | AGENTS.md Conventions for React/Next.js Repositories | AI Agent Workflows | Next.js, React | A | Active | https://agents.md/ |
| github-copilot-custom-instructions | GitHub Copilot Custom Instructions for Frontend | AI Agent Workflows | Next.js, React | A | Active | https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions |
| other-coding-agents-frontend-rules | Other Coding Agents: Frontend Rules (Windsurf, Cline, Roo, Gemini CLI, Aider, Codex) | AI Agent Workflows | Next.js, React | A | Active | https://agents.md/ |
| ai-ui-generation-tools | AI UI Generation Tools | AI Agent Workflows | Next.js, React | B | Active | https://ui.shadcn.com/docs/mcp |
| design-to-code-figma-workflow | Design-to-Code Figma Workflow | AI Agent Workflows | Next.js, React | A | Active | https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server |
| browser-automation-agent-workflow | Browser Automation Agent Workflow | AI Agent Workflows | Next.js, React | A | Active | https://github.com/microsoft/playwright-mcp |
| screenshot-driven-ui-iteration | Screenshot-Driven UI Iteration | AI Agent Workflows | Next.js, React | A | Active | https://code.claude.com/docs/en/best-practices |
| ai-accessibility-audit-workflow | AI Accessibility Audit Workflow | AI Agent Workflows | Next.js, React | A | Active | https://vercel.com/design/guidelines |
| ai-frontend-debugging-workflow | AI Frontend Debugging Workflow | AI Agent Workflows | Next.js, React | A | Active | https://nextjs.org/docs/app/guides/ai-agents |
| ai-frontend-code-review | AI Frontend Code Review (React + Next.js) | AI Agent Workflows | Next.js, React | A | Active | https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices |
| distinctive-frontend-design-for-agents | Distinctive Frontend Design for Agents | AI Agent Workflows | Next.js, React | A | Active | https://github.com/anthropics/skills/tree/main/skills/frontend-design |
| mcp-for-frontend-development | MCP Servers for Frontend Development (React/Next.js) | AI Agent Workflows | Next.js, React | A | Active | https://nextjs.org/docs/app/guides/mcp |
| frontend-agent-verification-loop | Frontend Agent Verification Loop | AI Agent Workflows | Next.js, React | A | Active | https://code.claude.com/docs/en/best-practices |
| nextjs-agent-rules-baseline (extra) | Next.js Agent Rules Baseline | AI Agent Workflows | Next.js, React | A | Active | https://nextjs.org/docs/app/guides/ai-agents |
| coding-agent-security-for-frontend (extra) | Coding-Agent Security for Frontend Projects | AI Agent Workflows | Next.js, React | A | Active | https://code.claude.com/docs/en/mcp |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| Claude Code — Skills | https://code.claude.com/docs/en/skills | Official docs | SKILL.md frontmatter fields, locations, substitutions, `!` context injection, invocation control, forked skills | Authoritative skill format | S | 2026-09-15 |
| Claude Code — Memory (CLAUDE.md) | https://code.claude.com/docs/en/memory | Official docs | Load order, @imports, `.claude/rules` paths frontmatter, AGENTS.md import/symlink, 200-line guidance | Project instruction design | S | 2026-09-15 |
| Claude Code — Hooks guide | https://code.claude.com/docs/en/hooks-guide | Official docs | PostToolUse formatter, PreToolUse exit-2 protection, Stop hook `stop_hook_active`, matchers | Deterministic enforcement | S | 2026-09-15 |
| Claude Code — Subagents | https://code.claude.com/docs/en/sub-agents | Official docs | Agent file frontmatter, tool restriction, reviewer examples | Reviewer/verifier agents | A | 2026-09-15 |
| Claude Code — MCP | https://code.claude.com/docs/en/mcp | Official docs | Scopes, `.mcp.json`, env expansion, approval, output limits, injection warning, tool permission names | MCP setup and security | S | 2026-09-15 |
| Claude Code — Best practices | https://code.claude.com/docs/en/best-practices | Official docs | Verification strategies, screenshot compare, explore-plan-code, CLAUDE.md include/exclude, adversarial review, failure patterns | Core agent workflow | S | 2026-09-15 |
| Agent Skills specification | https://agentskills.io/specification | Open spec | name/description constraints, optional fields, dirs, progressive disclosure, skills-ref validation | Cross-tool skill portability | S | 2026-09-15 |
| Anthropic — Skill authoring best practices | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | Official docs | Conciseness, degrees of freedom, descriptions, one-level references, eval-driven development, checklist | Skill quality | S | 2026-09-15 |
| anthropics/skills — frontend-design | https://github.com/anthropics/skills/tree/main/skills/frontend-design | Official open source | Design thinking steps, defaults to avoid, typography/color/motion rules | Anti-"AI slop" design | A | 2026-09-15 |
| anthropics/skills — webapp-testing | https://github.com/anthropics/skills/tree/main/skills/webapp-testing | Official open source | Reconnaissance-then-action, server lifecycle helper, networkidle pitfalls | Browser testing pattern (Python-based; adapt for TS) | B | 2026-09-15 |
| anthropics/skills — web-artifacts-builder | https://github.com/anthropics/skills/tree/main/skills/web-artifacts-builder | Official open source | React+Vite+shadcn artifact bundling, anti-slop notes | Generated UI context; not Next.js | B | 2026-09-15 |
| anthropics/skills — theme-factory | https://github.com/anthropics/skills/tree/main/skills/theme-factory | Official open source | Preset theme palettes/fonts | Low relevance (slides/docs) — not used | C | 2026-09-15 |
| Claude cookbook — Prompting for frontend aesthetics | https://github.com/anthropics/claude-cookbooks/blob/main/coding/prompting_for_frontend_aesthetics.ipynb | Official cookbook | Distributional convergence, per-dimension prompts, theme locking, fonts to avoid | Design prompting | A | 2026-09-15 |
| Claude blog — Improving frontend design through skills | https://claude.com/blog/improving-frontend-design-through-skills | Official blog | Rationale for skills vs system prompt, "right altitude" prompting | Design skill rationale | A | 2026-09-15 |
| vercel-labs/agent-skills (react-best-practices, composition-patterns, web-design-guidelines) | https://github.com/vercel-labs/agent-skills | First-party open source (MIT) | Priority rule categories, composition rules, UI review command | Best React/Next rule sets for agents | A | 2026-09-15 |
| Vercel Web Interface Guidelines + command.md | https://vercel.com/design/guidelines | Official guidelines | Interaction/animation/layout/content/forms/perf/design rules; review anti-pattern list and file:line format | UI quality and a11y rubric | A | 2026-09-15 |
| Next.js — AI agents guide | https://nextjs.org/docs/app/guides/ai-agents | Official docs | Bundled docs, managed AGENTS.md block, browserToTerminal, dev lock, fix menus, Next.js skills | Version-accurate agent setup | S | 2026-09-15 |
| Next.js — MCP guide (next-devtools-mcp) | https://nextjs.org/docs/app/guides/mcp | Official docs | `/_next/mcp`, tools (get_errors, get_routes, compile_route…), setup | Runtime verification | S | 2026-09-15 |
| vercel/next.js skills — next-dev-loop | https://github.com/vercel/next.js/tree/canary/skills | First-party open source | Four failure-mode verification loop, preflight, stop conditions | Verification loop design | A | 2026-09-15 |
| vercel-labs/agent-browser | https://github.com/vercel-labs/agent-browser | First-party open source | Ref-based CLI, react tree, vitals, security flags | Token-efficient browser alternative to MCP | A | 2026-09-15 |
| AGENTS.md | https://agents.md/ | Open convention | Format, nesting precedence, supported tools, migration | Canonical cross-agent instructions | A | 2026-09-15 |
| OpenAI Codex — AGENTS.md discovery | https://learn.chatgpt.com/docs/agent-configuration/agents-md | Official docs | Global/override files, root→cwd concatenation, 32 KiB limit, fallback filenames | Codex specifics | A | 2026-09-15 |
| Cursor — Rules | https://cursor.com/docs/context/rules | Official docs | `.cursor/rules` .mdc, description/globs/alwaysApply, rule types, 500-line guidance | Cursor rule format | A | 2026-09-15 |
| GitHub Docs — Copilot repository instructions | https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions | Official docs | copilot-instructions.md, .instructions.md applyTo/excludeAgent, AGENTS.md/CLAUDE.md support, feature matrix | Copilot format | A | 2026-09-15 |
| VS Code — Copilot custom instructions | https://code.visualstudio.com/docs/copilot/customization/custom-instructions | Official docs | instructions frontmatter, prompt files, custom agents, skills, locations | IDE-side Copilot | A | 2026-09-15 |
| Windsurf (Devin Desktop) — Rules & memories | https://docs.devin.ai/desktop/cascade/memories | Official docs | Activation modes, 12k/6k char limits, AGENTS.md scoping | Windsurf format | A | 2026-09-15 |
| Cline — Rules | https://docs.cline.bot/features/cline-rules | Official docs | `.clinerules/`, paths conditional rules, cross-tool rule detection | Cline format | A | 2026-09-15 |
| Roo Code — Custom instructions | https://roocodeinc.github.io/Roo-Code/features/custom-instructions | Official docs | `.roo/rules`, mode-specific rules, AGENTS.md loading | Roo format | B | 2026-09-15 |
| Gemini CLI — GEMINI.md | https://geminicli.com/docs/cli/gemini-md/ | Official docs | Hierarchy, @imports, `/memory`, `context.fileName` for AGENTS.md | Gemini format | A | 2026-09-15 |
| Aider — Conventions | https://aider.chat/docs/usage/conventions.html | Official docs | CONVENTIONS.md via `/read`, `read:` in .aider.conf.yml | Aider format | B | 2026-09-15 |
| microsoft/playwright-mcp | https://github.com/microsoft/playwright-mcp | Official open source | Options, snapshot vs vision, tool list, "not a security boundary", CLI vs MCP tradeoff | Browser automation | S | 2026-09-15 |
| ChromeDevTools/chrome-devtools-mcp | https://github.com/ChromeDevTools/chrome-devtools-mcp | Official open source | Tool reference (perf traces, lighthouse_audit, console, network), security disclaimer, telemetry opt-outs | Debugging/perf/a11y via browser | A | 2026-09-15 |
| shadcn/ui — MCP & registries | https://ui.shadcn.com/docs/mcp | Official docs | `shadcn mcp init --client`, registries in components.json, private auth | Component install via agent | A | 2026-09-15 |
| Figma — MCP server guide | https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server | Official docs | Remote vs desktop server, tools, prompt tips, access requirements | Design-to-code | A | 2026-09-15 |
| Figma developer docs — MCP | https://developers.figma.com/docs/figma-mcp-server/ | Official docs | Claude Code setup command, capabilities, limitations | Design-to-code | A | 2026-09-15 |
| v0 docs | https://v0.app/docs | Official docs | Stack (Next.js/Tailwind/shadcn), registry integration; thin prompting detail | AI UI generation | B | 2026-09-15 |
| github/awesome-copilot | https://github.com/github/awesome-copilot | Community (GitHub-maintained) | nextjs.instructions.md (Next 16-aligned), a11y.instructions.md (WCAG 2.2 anti-patterns), plugin install, third-party warning | Best-maintained community instruction library | B | 2026-09-15 |
| hesreallyhim/awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code | Community list | Category structure only; no frontend-specific knowledge extracted | Discovery index, not knowledge source | C | 2026-09-15 |
| PatrickJS/awesome-cursorrules | https://github.com/PatrickJS/awesome-cursorrules | Community list | Inventory of React/Next/Tailwind rule files; used only as examples of stale patterns (Next 14, persona filler). Raw rule files 404/403 at fetch time, so the rating rests on the repo listing | Popular but low-signal and often outdated | D | 2026-09-15 |
| cursor.directory | https://cursor.directory/ | Community site | Nothing extracted (HTTP 429); user-submitted, unmoderated rules | Rejected: unverifiable quality | D | 2026-09-15 |
| nextlevelbuilder/ui-ux-pro-max-skill | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | Community skill pack (MIT) | Style/palette/font datasets concept, text-resilience and anti-pattern notes (inspiration only) | Very popular, but requires Python + npm CLI installer, unvalidated "reasoning engine" claims, premium upsell; review before install | C | 2026-09-15 |
| dequelabs/axe-mcp-server | https://github.com/dequelabs/axe-mcp-server | Vendor open source (claimed) | Nothing (README 404 at fetch time) | Rejected/unverified; use @axe-core/playwright instead | D | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Skill file format | agentskills.io specification + Claude Code skills docs | Anthropic authoring best practices, VS Code/Copilot skills support | agent-skills-authoring |
| Cross-agent project instructions | agents.md | CLAUDE.md @AGENTS.md import, GEMINI.md context.fileName, Codex discovery, Windsurf/Cline/Roo AGENTS.md support | agents-md-conventions |
| React/Next.js rule sets | vercel-labs/agent-skills react-best-practices + Next.js AI agents guide | awesome-copilot nextjs.instructions.md, composition-patterns, awesome-cursorrules Next.js rules (stale parts dropped) | nextjs-agent-rules-baseline |
| UI quality checklist | Vercel Web Interface Guidelines | web-design-guidelines command.md, awesome-copilot a11y.instructions.md | ai-frontend-code-review, ai-accessibility-audit-workflow |
| Anti-"AI slop" design guidance | anthropics/skills frontend-design | Claude cookbook aesthetics notebook, Claude blog, web-artifacts-builder notes, ui-ux-pro-max anti-patterns | distinctive-frontend-design-for-agents |
| Browser control for agents | microsoft/playwright-mcp | chrome-devtools-mcp, agent-browser, anthropics webapp-testing | browser-automation-agent-workflow |
| Runtime verification loop | Claude Code best practices (verification) | next-dev-loop skill, next-devtools-mcp, Stop hook gate | frontend-agent-verification-loop |
| MCP/browser/secret security | Claude Code MCP + hooks docs | Playwright MCP security notes, chrome-devtools-mcp disclaimer, agent-browser security flags | coding-agent-security-for-frontend |

## Gaps

- No hands-on validation. None of the rule files, hooks or MCP configs were run in a real Next.js 16 repo; examples are built from docs.
- awesome-cursorrules and cursor.directory individual rules could not be read (404/403/429), so their D/C ratings rest on repo structure and summaries.
- v0, Lovable and Bolt prompting guidance is thin (v0 docs gave little detail; Lovable/Bolt not fetched). `ai-ui-generation-tools` is B.
- Figma MCP tool names, rate limits and seat rules change often; re-verify quarterly.
- Deque axe MCP server could not be verified; the a11y workflow relies on @axe-core/playwright and chrome-devtools-mcp `lighthouse_audit`.
- Two details are unverified: private shadcn registry `headers` shape in `components.json`, and the exact `logging.browserToTerminal` config shape.
- Next.js 16.x caching APIs (`use cache`, `updateTag`, `revalidateTag(tag,'max')`) and `proxy.ts` rename should be re-checked on each minor release.
- Agent eval harnesses for skills (measuring rule adherence) were not covered beyond the authoring checklist.
- Stars on some community packs (e.g., ui-ux-pro-max ~128k) were not independently checked for inflation.
