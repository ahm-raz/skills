# Skills Installed

Installed 2026-11-18 from `SKILLS_SETUP.md`. Every skill came from its official source through the official installer. None were written by hand.
Tooling: Node v24.22.1, npm 11.19.1, Claude Code 2.1.327, `impeccable` CLI 4.9.2, `skills` CLI 1.9.0.

## Summary

| # | Skill | Version / commit | Install path | Command that worked | Status |
|---|-------|------------------|--------------|---------------------|--------|
| 1 | impeccable | skill v4.9.1 (npm CLI 4.9.2), engine 0.1.24 | `.claude/skills/impeccable/`, `.claude/agents/impeccable-*.md` (4 agents) | `npx impeccable install --project --providers=claude --no-hooks -y` | Installed (hook **not** enabled) |
| 2 | shadcn | `shadcn-ui/ui@968d8cb` | `.claude/skills/shadcn/` | `npx skills add shadcn-ui/ui --skill shadcn -a claude-code -y --copy` | Installed |
| 3 | emil-design-eng | `emilkowalski/skills@64eb3de` | `.claude/skills/emil-design-eng/` | `npx skills add emilkowalski/skills --skill emil-design-eng -a claude-code -y --copy` | Installed |
| 4 | web-design-guidelines | `vercel-labs/agent-skills@1a2c79d` (metadata v1.0.0) | `.claude/skills/web-design-guidelines/` | `npx skills add https://github.com/vercel-labs/agent-skills --skill web-design-guidelines -a claude-code -y --copy` | Installed |
| 5 | agent-browser | `vercel-labs/agent-browser@deda8ef` | `.claude/skills/agent-browser/` | `npx skills add vercel-labs/agent-browser --skill agent-browser -a claude-code -y --copy` | Skill installed. CLI **not** installed (global install declined) |
| 6 | Mobbin | n/a | n/a | n/a | Skipped (your choice) |

`skills-lock.json` in the project root pins the four `skills`-CLI installs to source and commit.

Why `--copy`: on Windows the default symlink mode can fail without Developer Mode. Copying puts real files in `.claude/skills/`, so the folder can be copied to other projects.

## Per-skill review

### 1. impeccable
- **Scripts:** `scripts/impeccable` (sh launcher), `scripts/impeccable.cmd` (Windows launcher), `live-browser*.js`, `modern-screenshot.umd.js`, data JSON files (font index, command metadata), `engine-checksums.txt`.
- **Binary:** a native engine, `impeccable.exe` v0.1.24, installed at the **user level** in `C:\Users\Zain Goraya\.impeccable\bin\0.1.24\`. This is outside the project. The installer wrote it there without asking. Future projects share the cached binary.
- **Agents:** 4 subagents in `.claude/agents/` (asset-producer, documenter, finish-reviewer, manual-edit-applier).
- **Hooks:** none installed (`--no-hooks`). If you enable it, the optional hook runs the detector **after every edit** to UI files and again at session end. It is wired through `.claude/settings.local.json`.
- **Network:** the launcher downloads the engine from GitHub releases if it is missing. **Telemetry is ON** by default: "roll" usage data goes to impeccable.style, and it says no project names or code are sent. Turn it off with `npx impeccable telemetry off` or `DO_NOT_TRACK=1`. Account features (`login`, `health`, Pro rules) only run if you sign in. I did not sign in.

### 2. shadcn
- **Scripts:** `scripts/showcase-coverage.mjs`. There are also reference docs, rules, showcase assets and `evals/`.
- **Auto-run command:** SKILL.md contains `` !`npx shadcn@latest info --json` ``. Claude Code **runs this command every time the skill loads**, and it fetches the latest `shadcn` package from npm.
- **Pre-approved tools:** `allowed-tools` lets the skill run `npx/pnpm dlx/bunx shadcn@latest *` without prompting.
- **Network:** npm downloads, and the docs/registry lookups (`shadcn docs`, `search`, community registries).
- **Note:** it is only useful in React projects with shadcn/ui. This folder has no `components.json`, so I did not offer `npx shadcn@latest mcp init`.

### 3. emil-design-eng
- A single `SKILL.md`. No scripts, hooks, binaries or network calls. It links to easing.dev and easings.co as references only.

### 4. web-design-guidelines
- A single `SKILL.md`. No scripts, hooks or binaries.
- **Network:** on every run it **fetches its rules live** with WebFetch from `https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md`. The URL points at `main`, not a pinned commit, so the instructions can change upstream.

### 5. agent-browser
- A stub `SKILL.md` (51 lines). The real instructions come from the CLI (`agent-browser skills get core`), so **the skill does nothing until the CLI is installed**.
- **Pre-approved tools:** `allowed-tools: Bash(agent-browser:*)` lets it run any agent-browser command without prompting. The scope is broad: it can browse sites, drive Electron apps such as Slack, and send messages.
- **Network/binaries (only once the CLI is installed):** global npm package plus a downloaded Chromium.

## Out-of-date commands in SKILLS_SETUP.md

| Setup file says | What I used | Why |
|---|---|---|
| `npx impeccable install` (interactive) | `npx impeccable install --project --providers=claude --no-hooks -y` | Flags taken from `--help`: non-interactive, project scope, no hook until you approve it |
| `npx skills add shadcn/ui` | `npx skills add shadcn-ui/ui --skill shadcn ...` | The CLI reports "shadcn/ui has moved to shadcn-ui/ui". The repo has 2 skills, and only `shadcn` was wanted (`migrate-radix-to-base` was not installed) |
| `-a claude-code -y` (suggested) | Supported as-is, plus `--copy` | Confirmed in `npx skills --help` |

No command failed.

## Verify results
- `.claude/skills/` holds 5 skills. Each `SKILL.md` has `name` and `description` in its frontmatter (checked).
- Plugins: `claude plugin list` shows "No plugins installed".
- **`git status` could not run** because `F:\skills` is not a git repository. I checked the file system instead. The only new files are in `.claude/` (skills + agents) and `skills-lock.json`. No app code exists here, and none was touched. One change landed outside the project: Impeccable's engine in `~/.impeccable/bin/`.

## Still to do by hand
1. **Restart Claude Code**, then run **`/impeccable init`** in a project to create PRODUCT.md / DESIGN.md.
2. Optional: install the agent-browser CLI with `npm i -g agent-browser && agent-browser install` (global, downloads Chromium).
3. Optional: turn on the Impeccable hook per project with `npx impeccable hooks on`, or turn off telemetry with `npx impeccable telemetry off`.
4. Optional: Mobbin (`claude plugin marketplace add mobbin/skills` then `claude plugin install mobbin@mobbin`) needs a paid plan and a sign-in.

## Reusing this collection in other projects
- **Copy:** copy `.claude/skills/` (and `.claude/agents/` for Impeccable) into the other project.
- **Reinstall from the lock file:** copy `skills-lock.json` and run `npx skills experimental_install -a claude-code`. Then run the Impeccable install command above in that project, because Impeccable is not in the lock file.
- **All projects at once:** install at user level (`-g` / `impeccable install --user`) so the skills land in `~/.claude/skills/`. This is a global install, so I did not do it.
