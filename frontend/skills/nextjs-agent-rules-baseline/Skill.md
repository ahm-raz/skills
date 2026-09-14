# Next.js Agent Rules Baseline

## Summary
A deduplicated, version-aware rule set for AI coding agents working in React 19 + Next.js 16 App Router + TypeScript + Tailwind/shadcn repositories. It merges the useful parts of the most-cited community rule packs: Vercel's `react-best-practices`, `composition-patterns`, and Web Interface Guidelines; awesome-copilot's `nextjs.instructions.md`; and the Next.js "AI agents" guide. Outdated or generic rules are dropped. Paste it into one canonical `AGENTS.md` (or split it into path-scoped rule files) instead of stacking several overlapping community rule files.

## Category
AI Agent Workflows

## Subcategories
agent instructions, rule sets, Next.js App Router, React 19, Server Components, caching, composition, Tailwind, shadcn/ui, rule hygiene

## Problem It Solves
Community rule files (awesome-cursorrules, cursor.directory, copy-pasted `.cursorrules`) often:
- target Next.js 13/14 or the Pages Router;
- open with "You are an expert…" persona filler;
- repeat what linters already enforce;
- contradict each other when stacked.

Agents also lean on training data older than the installed framework version. The result is `getServerSideProps` in App Router code, synchronous `params`, `forwardRef` in React 19, `unstable_cache` everywhere, and `"use client"` on whole pages. This skill gives one short, current, verifiable baseline and a way to keep it current.

## When To Use
- Bootstrapping `AGENTS.md` / `CLAUDE.md` / `.cursor/rules` / `.github/instructions` for a React + Next.js repo.
- Replacing a pile of imported community rule files with one maintained set.
- Auditing an existing rule file for stale Next.js/React guidance.
- Giving a reviewer agent a compact rubric.

## When Not To Use
- Vite SPA without Next.js: keep only the React, composition, UI, and verification sections.
- Next.js ≤ 14 or Pages Router projects: most server/caching rules differ, so pin rules to the installed version.
- As a replacement for the framework docs. The rules point to docs; they don't restate APIs.

## Core Principles
1. **Installed version beats training data.** Tell the agent to read `node_modules/next/dist/docs/` (Next 16.2+) or the `.md` docs pages before writing framework code.
2. **Rules must be verifiable.** Each rule should be checkable by a linter, typecheck, test, build, or a reviewer reading a diff. Delete rules nobody can check.
3. **Linters enforce style; rules explain decisions.** Don't restate Prettier/ESLint config in prose.
4. **One canonical file, thin shims.** Keep `AGENTS.md` as the source of truth. Other tools import or point to it.
5. **Short beats complete.** Target under 200 lines always-on. Move task-specific material into skills or path-scoped rules.
6. **Priority-ordered.** Put the highest-impact rules first (waterfalls, bundle size, server/client boundary), following Vercel's CRITICAL→LOW ordering.

## Best Practices
- Start the file with **commands** (dev, typecheck, lint, test, build), because agents run what is listed.
- Name concrete paths (`app/`, `components/ui/` for shadcn, `lib/`, `server/`) rather than "keep files organized".
- Add a rule the second time an agent makes the same mistake. Prune rules the agent already follows without being told.
- Keep framework-managed blocks intact. Next 16.3 `next dev` upserts a `<!-- BEGIN:nextjs-agent-rules -->` block in `AGENTS.md`; write your rules outside it.
- Version-stamp the rule file ("Targets Next 16.x / React 19.x") so staleness is visible.
- For path-specific rules, use globs (`app/**/*.tsx`, `components/ui/**`) so server-only guidance isn't loaded for CSS edits.

## Implementation Guidance

### Distilled rule set (deduplicated)

**A. Server/client boundary (CRITICAL)**
- Components are Server Components by default. Add `"use client"` only at the smallest interactive leaf; never on `layout.tsx`/`page.tsx` just to use one hook.
- Pass only serializable, minimal props from server to client. Don't ship whole DB rows to the client.
- Never call `next/dynamic` with `{ ssr: false }` inside a Server Component. Move it into a client component and import that.
- Put server-only modules behind `import "server-only"`. Never import them from client files.
- Server Components shouldn't `fetch` your own Route Handlers. Call the shared function in `lib/` directly.

**B. Request APIs and routing (Next 15+/16)**
- `params` and `searchParams` are Promises in pages, layouts, and route handlers. `cookies()`, `headers()`, and `draftMode()` are async. Always `await` them.
- Reading request data makes a route dynamic. Isolate those reads behind `<Suspense>` so the rest can prerender.
- Next 16 renames `middleware.ts` to `proxy.ts`. Confirm against the installed docs before creating either.
- Use `<Link>`/`<a>` for navigation, never `onClick={() => router.push()}` on a div.

**C. Data fetching and waterfalls (CRITICAL)**
- Start independent async work in parallel (`Promise.all`, or create promises before awaiting).
- Move `await` into the branch that needs it. Check cheap conditions before expensive awaits.
- Stream slow sections with `<Suspense fallback>` instead of blocking the whole page.
- Deduplicate per-request reads with `React.cache()`. Use `after()` for non-blocking work such as logging and analytics.

**D. Caching (Next 16 Cache Components)**
- With `cacheComponents: true`, cache with the `"use cache"` directive plus `cacheLife()` and `cacheTag()`. Treat `unstable_cache` as legacy.
- After mutations, use `updateTag()` in Server Actions for read-your-writes. Use `revalidateTag(tag, 'max')` for stale-while-revalidate.
- When the dev overlay/terminal prints a blocking-prerender fix menu (`[stream]` / `[cache]` / `[block]`), pick one deliberately. Don't silence it.

**E. Server Actions and route handlers (security-critical)**
- Treat every Server Action as a public POST endpoint: authenticate, authorize, and validate input (Zod) inside the action.
- Return typed results. Don't throw raw errors containing internals.
- Route handlers validate input and return correct status codes.

**F. Bundle size (CRITICAL)**
- Import directly, not through barrel files (`import { Button } from "@/components/ui/button"`).
- Lazy-load heavy client-only widgets (charts, editors, maps) with `next/dynamic` from a client component.
- Load third-party scripts with `next/script` after hydration. Preload on intent (hover/focus) rather than eagerly.

**G. React 19 and composition**
- `ref` is a regular prop, so don't add `forwardRef`. Use `use(Context)` where conditional reads help.
- Prefer composition (compound components, `children`) over boolean-prop proliferation (`isCompact`, `hideHeader`…). Create explicit variants instead.
- Derive state during render. Don't mirror props into state with effects. Use functional `setState` and lazy initial state.
- Memoize only measured hot paths, or rely on the React Compiler if enabled. Don't wrap primitives in `useMemo`.
- Put `startTransition` / `useDeferredValue` around non-urgent updates.

**H. UI quality (from Web Interface Guidelines, frontend-relevant subset)**
- Use semantic elements first (`button`, `a`, `label`); every icon-only button gets an `aria-label`.
- Never use `outline-none` without a `focus-visible:` replacement, or `transition-all` (list the properties).
- Honor `prefers-reduced-motion` (`motion-safe:` / `motion-reduce:` in Tailwind).
- Give images explicit dimensions (`next/image` with `width`/`height` or `fill` + sized parent). Loading skeletons match the final layout.
- Mobile inputs ≥16px; never disable zoom; never block paste.
- Keep filters/tabs/pagination state in the URL. Format numbers and dates with `Intl`; use `tabular-nums` for numeric columns.

**I. Styling**
- Tailwind v4: define tokens once in CSS `@theme`, and use semantic tokens (`bg-background`, `text-muted-foreground`) rather than raw hex.
- Add shadcn components through the CLI/registry (`npx shadcn@latest add …`) and edit them in `components/ui`. Don't hand-roll duplicates.
- Merge conditional classes with `cn()`. No inline style objects for themeable values.

**J. TypeScript and tooling**
- `strict: true`. No `any`, and no `@ts-ignore` without a linked reason.
- Next 16: run ESLint through the ESLint CLI (`next lint` is removed). Turbopack is the default; its config lives in the top-level `turbopack` key.
- Environment: secrets live only in `.env.local` / platform env. Anything prefixed `NEXT_PUBLIC_` is inlined into the client bundle.

### Rules dropped as stale or low-value (seen in community packs)
| Stale rule | Why dropped |
|---|---|
| "Use `getServerSideProps`/`getStaticProps`" | Pages Router only |
| "Minimize `use client`, favor RSC" as the *only* guidance | Too vague to verify; replaced by A |
| "Use `nuqs` for URL state" as a mandate | Library choice; belongs in project-specific rules |
| `experimental.turbo`, `next lint` | Removed/renamed in Next 16 |
| "You are a senior expert in…" | Persona filler, no measurable effect |
| Re-stating Prettier/ESLint formatting | Enforced by tooling |

## Recommended Workflow
1. Detect versions: `next`, `react`, `tailwindcss`, and shadcn `components.json` from `package.json`.
2. Run `next dev` once (16.3+) so the managed docs pointer block is generated, or add it yourself.
3. Copy only the relevant sections (A–J) into `AGENTS.md` under "Conventions". Add project paths and commands.
4. Add thin shims: `CLAUDE.md` containing `@AGENTS.md`; Cursor/Copilot/Windsurf read `AGENTS.md` natively.
5. Move long or path-specific parts (caching, UI checklist) into path-scoped rules or skills.
6. Validate: give the agent 3 representative tasks (new page with data, form with Server Action, interactive widget) and review diffs against the rules.
7. Prune quarterly and on every framework major upgrade.

## Patterns
- **Docs-pointer header:** first rule says "read `node_modules/next/dist/docs/<topic>` before editing framework code".
- **Command block first:** `pnpm typecheck && pnpm lint && pnpm test && pnpm build` as the definition of done.
- **Priority tags:** `[CRITICAL]` / `[HIGH]` prefixes so reviewers and agents triage consistently.
- **Path-scoped split:** `app/**` gets the server/caching rules, `components/ui/**` gets the shadcn/a11y rules, `**/*.test.tsx` gets the testing rules.

## Anti-Patterns
- **Stacking 3–5 community rule files.** They conflict and the agent picks arbitrarily. Fix: merge into one baseline.
- **Unversioned rules.** Silent drift after upgrades. Fix: stamp versions and re-verify on upgrade.
- **Rules as tutorials.** Token waste and lower adherence. Fix: one line per rule, and link to the docs path.
- **Prose rules for must-always behavior** (e.g., "never edit `.env`"). Fix: enforce with hooks, permissions, or CI.

## Accessibility
Section H is the minimum. Map it to WCAG 2.2:
- 2.4.7 / 2.4.11 focus visible and not obscured;
- 4.1.2 name, role, value for icon buttons;
- 2.3.3 motion via reduced motion;
- 1.4.4 resize text (never disable zoom);
- 2.5.8 target size ≥24px.

Pair with automated checks (jsx-a11y, axe) so the rules are verified rather than trusted.

## Responsive Design
Include one rule: verify at mobile (375), tablet (768), desktop (1280), and wide (1920); respect safe-area insets; don't autofocus inputs on mobile. Put layout mechanics in the styling skills, not the rule file.

## Performance
The ordering itself is a performance strategy: waterfalls → bundle → server → re-render → micro-optimizations. Tell agents not to apply LOW-priority JS micro-optimizations before the CRITICAL categories are clean.

## Security
- Server Actions are public endpoints: authorize inside them.
- Never expose secrets through `NEXT_PUBLIC_`. Never read `.env*` into agent output.
- Avoid `dangerouslySetInnerHTML` unless the content is sanitized.
- Rule files are executable context. Review community rules before adopting them, since hidden instructions or unicode tricks in pasted rules are a prompt-injection vector.

## Testing
- Encode rules as checks where possible: ESLint (`react-hooks`, `jsx-a11y`, `@next/next`), `tsc --noEmit`, `next build`, Playwright + axe.
- Keep a small eval set of agent tasks and re-run it after editing the rule file to confirm behavior shifts.

## Tooling
- `eslint-config-next`, `eslint-plugin-jsx-a11y`, TypeScript strict: active, and they enforce much of the rule set.
- `next-devtools-mcp`: active (Next 16+), reports compile/runtime errors against the rules.
- Vercel `agent-skills` (`react-best-practices`, `composition-patterns`, `web-design-guidelines`): MIT, active. Install as on-demand skills rather than always-on rules.
- awesome-copilot `nextjs.instructions.md`: good current community example (aligned to Next 16.1).

## Framework Notes
- **Next.js (App Router, 16.x):** all sections apply. Re-check B and D on each minor release; caching APIs are still evolving.
- **React (Vite SPA):** drop A, B, D, and E. Keep C (client fetching via TanStack Query/SWR dedup), F (`React.lazy`), G, H, I, and J.

## AI Agent Guidance
- Do: read the installed docs before framework code; `await` params; keep `"use client"` at leaves; authorize in Server Actions; run typecheck/lint/build before claiming done.
- Don't: use Pages Router APIs, `forwardRef`, `unstable_cache` in new code, `transition-all`, `outline-none` without replacement, or barrel imports of heavy libraries.
- Before done: cite which rules applied, show command output, and flag any rule deliberately broken with a reason.

## Examples
```markdown
<!-- AGENTS.md (excerpt) — Targets Next 16.3 / React 19.2 / Tailwind 4 -->
## Commands
- Dev: `pnpm dev` (reuse a running server; see .next/dev/lock)
- Verify: `pnpm typecheck && pnpm lint && pnpm test && pnpm build`

## Conventions
- [CRITICAL] Server Components by default; `"use client"` only on interactive leaves in `components/`.
- [CRITICAL] `await params` / `await searchParams` / `await cookies()`.
- [CRITICAL] Parallelize independent fetches; stream slow sections with <Suspense>.
- [CRITICAL] Server Actions in `app/**/actions.ts`: `auth()` + Zod parse first line.
- [HIGH] Cache with "use cache" + cacheTag; mutate then updateTag().
- [HIGH] shadcn components live in `components/ui`; add via `pnpm dlx shadcn@latest add`.
- [HIGH] No barrel imports; lazy-load charts/editors.
- [MEDIUM] No transition-all; focus-visible rings required; motion-reduce variants.
```

```tsx
// app/products/[slug]/page.tsx — rules B, C, D applied
import { Suspense } from "react";
import { getProduct, getReviews } from "@/lib/products";
import { Reviews } from "./reviews";

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const reviews = getReviews(slug); // start early, don't await yet
  const product = await getProduct(slug);
  return (
    <article>
      <h1 className="text-balance text-3xl font-semibold">{product.name}</h1>
      <Suspense fallback={<p className="text-muted-foreground">Loading reviews…</p>}>
        <Reviews promise={reviews} />
      </Suspense>
    </article>
  );
}
```

## Related Skills
- [agents-md-conventions](../agents-md-conventions/Skill.md) — where this rule set lives
- [cursor-rules-for-frontend](../cursor-rules-for-frontend/Skill.md) — splitting the set into `.mdc` rules
- [github-copilot-custom-instructions](../github-copilot-custom-instructions/Skill.md) — path-scoped `.instructions.md` variant
- [ai-frontend-code-review](../ai-frontend-code-review/Skill.md) — using the set as a review rubric
- [frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md) — turning rules into checks
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — depth on section A
- [nextjs-caching-and-revalidation](../nextjs-caching-and-revalidation/Skill.md) — depth on section D
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — depth on section E
- [react-component-composition](../react-component-composition/Skill.md) — depth on section G
- [coding-agent-security-for-frontend](../coding-agent-security-for-frontend/Skill.md) — securing rule files and agents

## Sources
- [vercel-labs/agent-skills — react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) — Open Source (MIT) — priority categories and rule themes
- [vercel-labs/agent-skills — composition-patterns](https://github.com/vercel-labs/agent-skills/tree/main/skills/composition-patterns) — Open Source (MIT) — composition and React 19 rules
- [Vercel Web Interface Guidelines](https://vercel.com/design/guidelines) — Official (Vercel) — UI quality subset
- [Next.js: set up your project for AI coding agents](https://nextjs.org/docs/app/guides/ai-agents) — Official — bundled docs, managed AGENTS.md block, error fix menus
- [Next.js MCP guide](https://nextjs.org/docs/app/guides/mcp) — Official — runtime verification tooling
- [github/awesome-copilot — nextjs.instructions.md](https://github.com/github/awesome-copilot/blob/main/instructions/nextjs.instructions.md) — Community — Next 16 caching and tooling rules
- [PatrickJS/awesome-cursorrules](https://github.com/PatrickJS/awesome-cursorrules) — Community — reviewed for stale patterns (not adopted verbatim)
- [Claude Code memory docs](https://code.claude.com/docs/en/memory) — Official — size guidance and AGENTS.md import

## License / Usage Notes
Rules are paraphrased and merged from MIT-licensed Vercel skills, Vercel's public guidelines, Next.js docs (MIT repo), and community instruction files. No text is copied verbatim beyond short API identifiers. Re-verify framework-specific rules against installed docs; APIs noted here reflect Next 16.x as of the verification date.

## Quality Tier
A — built from strong official and first-party sources with explicit deduplication. Caching and proxy details move quickly and need per-upgrade re-verification.

## Status
Active

## Last Verified
2026-09-15
