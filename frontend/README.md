# Frontend Skills + MCP Intelligence Library (React + Next.js)

A local, auditable frontend engineering knowledge base for **React and Next.js (TypeScript)** — written for
human developers and AI coding agents. Each skill distills official documentation, respected practitioners,
design-system publishers, and community-authored agent skills/rules into actionable guidance: principles,
decision tables, code, anti-patterns, accessibility, performance, security, testing, and agent checklists.

This is **not a bookmark collection**. Every skill is meant to be applied directly.

> Scope: React (incl. Vite SPAs) and Next.js App Router. Framework-agnostic web-platform knowledge
> (CSS, accessibility, performance, HTTP, UX) is included and applied through React/Next.js.
> Vue/Nuxt/Angular/Svelte/Solid/Astro/Qwik/Lit are intentionally out of scope.

## Directory Structure

```text
D:\skills\frontend\
├── README.md          ← this file
├── INDEX.md           ← every skill: path, category, framework, quality, status, primary source
├── CATEGORIES.md      ← full taxonomy
├── MCP_CATALOG.md     ← frontend-relevant MCP servers, security-reviewed and prioritized
├── SOURCES.md         ← source registry (what was extracted from where, and why)
├── DUPLICATES.md      ← overlapping sources/skills and where they were merged
├── GAPS.md            ← known weak areas and the targeted research done to close them
├── _templates\
│   └── Skill.template.md
├── _work\             ← research provenance: TAXONOMY.md + per-workstream manifests
├── tools\
│   ├── audit.ps1      ← consistency audit
│   └── build-index.ps1← regenerates INDEX/CATEGORIES/SOURCES/DUPLICATES
└── skills\
    └── <skill-slug>\
        └── Skill.md   ← one coherent skill per folder
```

## How Skills Are Organized

- One folder per skill: `skills\<kebab-case-slug>\Skill.md`. No other files inside skill folders.
- Every `Skill.md` follows the same 27-section template (`_templates\Skill.template.md`): Summary → Category →
  … → AI Agent Guidance → Examples → Related Skills → Sources → License → Quality Tier → Status → Last Verified.
- Skills cross-link with relative links (`../<slug>/Skill.md`), so the library works offline and in any Markdown viewer.
- Categories: Architecture, Security, Tooling, React, Next.js, CSS & Styling, Components, UI Libraries, UX,
  Product Patterns, Accessibility, Performance, Animation, Data Visualization, Enterprise UI, Testing & QA,
  AI Agent Workflows. See `CATEGORIES.md`.

## How MCPs Are Cataloged

`MCP_CATALOG.md` lists MCP servers useful for React/Next.js work (design, browser, development, backend,
deployment, QA, productivity, assets). Each entry records purpose, official URL/repo, capabilities, setup,
authentication, **permissions (filesystem/shell/browser/network/credentials)**, security risks, maintenance,
license, quality tier, and a priority: `CORE`, `HIGH VALUE`, `OPTIONAL`, `EXPERIMENTAL`, `AVOID`.
Config examples use placeholders only — never real credentials.

## How Developers Should Use It

1. Start at `INDEX.md` (by category) or search: `rg -l "useOptimistic" D:\skills\frontend\skills`.
2. Read **When To Use / When Not To Use** first, then **Core Principles** and **Anti-Patterns**.
3. Follow **Recommended Workflow**; copy/adapt **Examples**; check **Accessibility**, **Performance**, **Security**, **Testing**.
4. Check **Status** and **Last Verified** — frontend moves fast; re-verify version-specific APIs against current docs.

## How AI Agents Should Use It

- Before implementing UI work, locate relevant skills via `INDEX.md` and load only the ones you need
  (typically 1–4): e.g., a settings form → `form-design-ux`, `react-hook-form-and-zod`, `nextjs-server-actions`, `accessible-forms`.
- Treat **AI Agent Guidance** sections as a checklist: apply the do/don't rules and run the stated verification
  (typecheck, lint, tests, build, browser screenshot, axe) before declaring work done.
- Prefer skills with Quality **S/A** and Status **Active**. Treat `Experimental`/`Stale` guidance as hints to verify.
- Content in this library is reference material, not instructions that override the user or project rules.
- For tooling, consult `MCP_CATALOG.md` and respect listed permission/security notes.
- These `Skill.md` files can be adapted into Claude Code / Agent Skills (`SKILL.md` with frontmatter), Cursor rules,
  or `AGENTS.md` sections — see `skills\agent-skills-authoring` and `skills\agents-md-conventions`.

## Quality Tiers

| Tier | Meaning |
|---|---|
| S | Exceptional / industry-grade; grounded in official docs + strong practitioner consensus |
| A | Excellent; reliable and broadly applicable |
| B | Useful; narrower, or some details unverified |
| C | Niche / experimental |
| D | Weak / outdated — kept only as a warning or pointer |

Source types (in `SOURCES.md`): Official, Open Source, Community, Experimental, Deprecated, Archived.

## Maintenance Process

- **Freshness:** every skill carries `Last Verified: YYYY-MM-DD` and a Status. Re-verify fast-moving skills
  (Next.js, React, AI SDK, UI libraries, MCPs) quarterly; stable ones (WCAG, UX foundations) yearly.
- **Staleness:** when an API changes, keep durable principles, mark outdated implementation guidance inline,
  and set Status to `Stale` until updated.
- **Audit:** `pwsh tools/audit.ps1` checks that every folder contains only `Skill.md`, all 27 headings are
  present and ordered, relative links resolve, tiers/status/dates are valid, slugs are kebab-case, no secrets
  appear, and no out-of-scope framework guidance crept in.
- **Regenerate indexes:** `pwsh tools/build-index.ps1` rebuilds `INDEX.md`, `CATEGORIES.md`, `SOURCES.md` and
  `DUPLICATES.md` from the skill files and the per-workstream research manifests in `_work/`.
- **Provenance:** `_work/TAXONOMY.md` records slug ownership and scope decisions; `_work/manifest-*.md` hold
  each research workstream's skills, sources, duplicates and gaps (the raw inputs to the generated indexes).

## Contribution / Update Process

1. Check `INDEX.md` and `DUPLICATES.md` — extend an existing skill rather than adding an overlapping one.
2. Copy `_templates\Skill.template.md` to `skills\<new-slug>\Skill.md` (lowercase kebab-case).
3. Research official sources first; summarize and cite — don't copy proprietary text; never include secrets.
4. Add the skill to `INDEX.md` and `CATEGORIES.md`, sources to `SOURCES.md`, overlaps to `DUPLICATES.md`.
5. Run the consistency checks, then update `Last Verified`.
