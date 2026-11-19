# Frontend Design Skills Setup

This file tells Claude Code how to install the real, official frontend design skills into this project.

## Rules (read first)

1. **Install the real skills from their official sources.** Never write a SKILL.md from memory and never create a fake or "equivalent" skill.
2. **Install at project level** so everything lands in `.claude/skills/` (or as a project-scoped plugin). Do not install globally unless a step says so.
3. **Check before you run.** Installer flags change. Before each installer, run its `--help` and use the flags it actually supports. Prefer non-interactive flags when they exist.
4. **If a command fails,** open the repo README, find the current install command, and try that. If it still fails, stop that step, record the error, and move on. Do not invent a workaround.
5. **Review before trusting.** After each install, read the skill's `SKILL.md` and list any scripts, hooks, or binaries it adds. Flag anything that sends data out or runs on every edit.
6. **Ask me before:** any global install (`npm i -g`), any login or sign-in, and any hook that runs automatically.
7. Do not edit my app code. This task only sets up skills.

## Skills to install (in this order)

| # | Skill | Job | Source | Starting command |
|---|-------|-----|--------|------------------|
| 1 | Impeccable | Visual direction, DESIGN.md, critique, polish | https://github.com/pbakaus/impeccable | `npx impeccable install` (choose Claude Code + this project) |
| 2 | shadcn/ui skill | Component foundation | https://ui.shadcn.com/docs/skills | `npx skills add shadcn/ui` |
| 3 | emil-design-eng | Motion and micro-interactions | https://github.com/emilkowalski/skills | `npx skills add emilkowalski/skills --skill emil-design-eng` |
| 4 | web-design-guidelines | UI, accessibility and UX audit | https://github.com/vercel-labs/agent-skills | `npx skills add https://github.com/vercel-labs/agent-skills --skill web-design-guidelines` |
| 5 | agent-browser | Visual QA (open page, screenshots) | https://github.com/vercel-labs/agent-browser | `npx skills add vercel-labs/agent-browser` |
| 6 | Mobbin (optional, paid) | Real app screens as references | https://github.com/mobbin/skills | `claude plugin marketplace add mobbin/skills` then `claude plugin install mobbin@mobbin` |

### Notes per skill

- **All `npx skills add` commands:** run `npx skills add --help` first. If it supports an agent flag (for example `-a claude-code`) and a yes flag (for example `-y`), use them so the skill goes to `.claude/skills/` without prompts.
- **Impeccable:** run `npx impeccable install --help` first and use project scope with the Claude provider. It may offer a design hook. Ask me before enabling it. Do not sign in to any account.
- **shadcn/ui:** only useful if the project uses React. If there is a `components.json`, also offer to run `npx shadcn@latest mcp init --client claude`, but ask first.
- **agent-browser:** the skill needs the CLI. Ask me before running `npm i -g agent-browser && agent-browser install` (it downloads a browser).
- **Mobbin:** needs a paid Mobbin plan and a browser sign-in. Ask me first. If I say no, skip it.

## Do NOT install

Do not add these alongside Impeccable. They also try to control the overall look and will conflict: Anthropic `frontend-design`, Taste Skill, UI UX Pro Max, `web-design-engineer`, `baseline-ui`.

## Verify

After all installs:

1. List `.claude/skills/` and show the folder tree (2 levels deep).
2. For each skill, confirm `SKILL.md` exists and has `name` and `description` in its frontmatter.
3. List installed plugins and their scope.
4. Confirm nothing outside `.claude/`, `.agents/`, lock files, or skill config files was changed (use `git status`).

## Report

Create `SKILLS_INSTALLED.md` in the project root with:

- A table: skill, version or commit if shown, install path, exact command that worked, status (installed / skipped / failed).
- For each skill: scripts, hooks or binaries it added, and anything it sends over the network.
- Any command in this file that was out of date, and the correct one you used.
- What I still need to do by hand (logins, restarts, `/impeccable init`).

Finish by telling me to restart Claude Code, then run `/impeccable init`.
