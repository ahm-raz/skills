# UI/UX Skills: Setup and Usage Guide

How to bring this skills collection into a project, set up each skill, and use them together to design UI/UX screens.

`SKILLS_INSTALLED.md` covers what was installed, the versions and the security notes. This file covers **how to use the skills**.

---

## 0. Bring the collection into a project

Pick one option, then **restart Claude Code** in that project.

**Option A: copy (fastest, works offline)**
```powershell
# from the target project root
Copy-Item -Recurse F:\skills\.claude\skills .claude\skills
Copy-Item -Recurse F:\skills\.claude\agents .claude\agents    # Impeccable's helper agents
```
Impeccable's engine is cached in `~\.impeccable\bin\` and is shared by every project on this machine. On a new machine, the launcher downloads it on first run.

**Option B: reinstall from source (latest versions)**
```powershell
Copy-Item F:\skills\skills-lock.json .
npx skills experimental_install -a claude-code            # shadcn, emil, web-design-guidelines, agent-browser
npx impeccable install --project --providers=claude --no-hooks -y
```

**Check it worked:** in Claude Code, type `/` and confirm `impeccable`, `emil-design-eng` and `web-design-guidelines` appear. `shadcn` and `agent-browser` don't appear in the `/` menu. They load automatically when a request matches them.

**Do not add** Anthropic `frontend-design`, Taste Skill, UI UX Pro Max, `web-design-engineer` or `baseline-ui` next to Impeccable. They compete with it over the overall look.

---

## 1. What each skill is for

| Skill | Role | How it gets used | Needs setup? |
|---|---|---|---|
| **impeccable** | Lead designer: visual direction, PRODUCT.md / DESIGN.md, build, critique, polish | `/impeccable <command>` or plain design requests | Yes: `/impeccable init` once per project |
| **shadcn** | Component foundation (React + Tailwind) | Loads automatically in projects with `components.json` | Yes, if the project uses React |
| **emil-design-eng** | Motion, micro-interactions, the feel of interactions | `/emil-design-eng`, or loads for interaction-polish questions | No |
| **web-design-guidelines** | Accessibility / UX / best-practice audit | `/web-design-guidelines <files>` | No (needs internet) |
| **agent-browser** | Visual QA: open pages, click, take screenshots | Loads automatically for "open / screenshot / test this page" | Yes: install the CLI |

---

## 2. Per-skill setup and usage

### 2.1 Impeccable: design direction (start here)

**One-time setup per project**
1. Restart Claude Code after installing.
2. Run `/impeccable init`. It scans the repo, asks up to three focused questions per round (users, what the product does, constraints, platform, and the stack if none exists yet), then writes **PRODUCT.md**.
3. Create **DESIGN.md**:
   - Existing UI: run `/impeccable document`. It records the current design system from the code.
   - New product or redesign: just ask for the screen, for example *"design the onboarding screen"*. Impeccable's new-work flow picks a visual direction and writes DESIGN.md.
4. Optional: run `/impeccable foundations` for a checklist of product basics (404 page, icons, secrets, CI).

**Optional extras (each changes behavior, so turn on deliberately)**
- **Design detector hook:** `/impeccable hooks on` (or `npx impeccable hooks on`). It runs the detector after every UI file edit and again when the session ends. It writes to `.claude/settings.local.json`. Turn it off with `/impeccable hooks off`.
- **Live mode:** `/impeccable live` lets you pick elements in the browser and iterate on variants. The project's dev server has to be running, and the first run may add `.impeccable/live/config.json`.
- **Telemetry:** on by default. Turn it off with `npx impeccable telemetry off`.
- Never needed: `impeccable login`. Signing in only unlocks Pro rules and account features.

**Commands**

| Stage | Command | Use it to |
|---|---|---|
| Plan | `/impeccable shape [feature]` | Plan the UX/UI before any code is written |
| Build | *(plain request)* | "Build the pricing page", "design a settings screen" |
| Build | `/impeccable extract [target]` | Pull repeated styles and components into the design system |
| Evaluate | `/impeccable critique [target]` | Get a scored UX design review |
| Evaluate | `/impeccable audit [target]` | Check accessibility, performance and responsiveness |
| Refine | `polish` · `harden` · `distill` · `onboard` | Final pass · errors/i18n/edge cases · simplify · first-run and empty states |
| Tune | `bolder` · `quieter` · `colorize` · `typeset` · `layout` | Make bland designs bolder · tone down loud ones · add color · fix typography · fix spacing and hierarchy |
| Enhance | `animate` · `delight` · `overdrive` | Add purposeful motion · add personality · push past conventional limits |
| Fix | `clarify` · `adapt` · `optimize` | Improve UX copy · adapt for screen sizes · fix UI performance |
| Iterate | `live` · `generate [n] [action] [element]` | Compare variants in the browser |
| Upkeep | `doctor` · `hooks status` | Repair stale context files · check hook wiring |

`/impeccable` with no argument shows a menu based on the project's current state.

**Tips**
- Say which surface you mean. Impeccable designs by **mode**: Persuade (landing pages, pricing), Operate (app UI, dashboards), Read (docs) and Experience (portfolios). A dashboard gets restraint, and a landing page gets boldness.
- A clear brief wins. If you pin a font, palette or era, Impeccable follows it.
- "Refine" keeps the current look. "Redesign" replaces it. Say which one you want.

---

### 2.2 shadcn: component foundation (React projects only)

**Setup**
1. The project must be React + Tailwind (Next.js, Vite, Remix and so on).
2. In a new or existing project, ask Claude to *"set up shadcn"*, or run it yourself:
   ```bash
   npx shadcn@latest init                   # creates components.json and offers the preset builder
   npx shadcn@latest init --preset <code>   # if you have a preset from ui.shadcn.com/create
   ```
3. Optional, for MCP registry search:
   ```bash
   npx shadcn@latest mcp init --client claude   # writes .mcp.json, then restart Claude Code
   ```

**Usage**
- The skill loads automatically once `components.json` exists. On load it runs `npx shadcn@latest info --json`, so Claude knows your aliases, Tailwind version, Radix vs Base UI, icon library and installed components.
- Ask in plain words: *"add a settings page with tabs and a form"*, *"build a dashboard with sidebar, cards and a chart"*, *"apply preset abc123"*, *"update the dialog component"*.
- Rules it enforces: use existing components first; use semantic colors (`bg-primary`, not `bg-blue-500`); lay out forms with `FieldGroup` + `Field`; every Dialog/Sheet needs a Title; use `gap-*`, not `space-y-*`. Updates are previewed with `--dry-run` / `--diff` first.

**With Impeccable:** Impeccable sets the visual direction (DESIGN.md), and shadcn supplies the components. Ask Impeccable to *"apply DESIGN.md to the shadcn theme"*, and it edits the CSS variables rather than overriding component styles.

---

### 2.3 emil-design-eng: motion and micro-interactions

**Setup:** none.

**Usage**
- Run `/emil-design-eng`. On its first run it answers with a ready line and waits for your question.
- Ask questions like:
  - *"Should this dropdown animate, and with what easing and duration?"*
  - *"Review the button and popover interactions in `components/menu.tsx`."*
  - *"Make this toast stack feel like Sonner."*
  - *"Add a drag-to-dismiss gesture to this sheet."*
- Reviews come back as a **Before/After table**.
- Topics it covers: whether something should animate at all, easing and duration, spring animations, origin-aware popovers, tooltip delays, CSS transitions vs keyframes, `@starting-style`, clip-path tricks, momentum drag, `prefers-reduced-motion`, and animating only transform/opacity for performance.

**With Impeccable:** use `/impeccable animate` for overall motion direction, then `emil-design-eng` to fine-tune individual interactions.

---

### 2.4 web-design-guidelines: compliance audit

**Setup:** none. It needs internet, because it downloads the latest rules from Vercel's `web-interface-guidelines` repo (`main` branch) on each run.

**Usage**
```
/web-design-guidelines src/app/**/*.tsx
/web-design-guidelines components/checkout/
```
- Without a path, it asks which files to review.
- Findings come back as terse `file:line` entries covering accessibility, focus states, forms, typography, performance, navigation and similar topics.
- Use it before shipping, after `/impeccable polish`.

---

### 2.5 agent-browser: visual QA

**Setup (one-time per machine, global)**
```bash
npm i -g agent-browser
agent-browser install          # downloads Chromium
agent-browser skills get core  # check it works
```
Until the CLI is installed, this skill does nothing.

**Usage**
- Start your dev server, then ask: *"open http://localhost:3000 and screenshot the home page at mobile and desktop"*, *"click through the signup flow and report anything broken"*, or *"dogfood the dashboard and list bugs"*.
- Claude loads `agent-browser skills get core` first, then works from accessibility snapshots and `@eN` element references.
- Extra guides are served by the CLI: `dogfood` (exploratory QA), `modern-web-guidance`, `electron`, and others. Run `agent-browser skills list` to see them all.

**Caution:** once installed, the skill can run any `agent-browser` command without a permission prompt, including driving Slack or other Electron apps. Keep requests specific to the pages you want tested.

---

## 3. Recommended workflow for a new screen

```
1. /impeccable init                 → PRODUCT.md (once per project)
2. /impeccable shape <feature>      → agree on UX before code
3. "Build the <screen>"             → Impeccable sets direction + DESIGN.md
                                       shadcn supplies components (React)
4. /impeccable critique <screen>    → design review
5. /impeccable animate <screen>     → motion direction
   /emil-design-eng                 → fine-tune interactions
6. agent-browser                    → screenshots at each breakpoint, click-through
7. /impeccable audit + /web-design-guidelines <files>  → a11y / UX compliance
8. /impeccable polish <screen>      → final pass
```

For an **existing** UI: `/impeccable init` → `/impeccable document` → `/impeccable critique` → then the refine commands.

---

## 4. Per-project checklist

- [ ] Skills copied or installed into `.claude/skills/` (+ `.claude/agents/`)
- [ ] Claude Code restarted
- [ ] `/impeccable init` → PRODUCT.md
- [ ] DESIGN.md (`/impeccable document` or first new-work request)
- [ ] React project? `npx shadcn@latest init` → `components.json`
- [ ] Optional: `npx shadcn@latest mcp init --client claude`
- [ ] Optional: `/impeccable hooks on`
- [ ] agent-browser CLI installed on this machine (one-time)

## 5. Troubleshooting

| Problem | Fix |
|---|---|
| A skill doesn't show up | Restart Claude Code. Check that `.claude/skills/<name>/SKILL.md` exists. |
| Impeccable says "Context loading did not run" | The engine is missing or blocked. Run `.claude/skills/impeccable/scripts/impeccable.cmd context` in a terminal (it downloads the engine on first run), or run `npx impeccable install --project --providers=claude --force`. |
| Impeccable context is stale after an upgrade | `/impeccable doctor` |
| shadcn skill errors about no `components.json` | Run `npx shadcn@latest init` first, or ignore it in non-React projects. |
| web-design-guidelines can't fetch its rules | It needs internet access to `raw.githubusercontent.com`. |
| agent-browser commands not found | Install the CLI globally (section 2.5). |
| Update everything | `npx skills update -p` and `npx impeccable update` |
