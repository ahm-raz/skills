# AI UI Generation Tools

## Summary
How to use AI UI generators (v0, Claude artifacts built with the web-artifacts-builder skill, shadcn registry-driven generation, and community "design intelligence" skill packs) to produce React/Next.js UI, and how to bring that output into a real Next.js App Router codebase without importing generic styling, accessibility debt, or duplicated primitives. The skill treats generated UI as a draft that must be merged into your design tokens, component library, and verification loop.

## Category
AI Agent Workflows

## Subcategories
v0, shadcn registry, Claude artifacts, prototyping, code integration, design systems, generated-code hardening

## Problem It Solves
Generators produce plausible screens in seconds, but the output usually (a) re-implements primitives you already have, (b) hardcodes colors/spacing instead of using tokens, (c) converges on the same "AI default" look, (d) skips states (empty, error, loading), accessibility and performance details, and (e) assumes a different stack version than your repo. Teams then paste it in and accumulate inconsistency. This skill defines when generation is appropriate and a repeatable intake process that turns a draft into production code.

## When To Use
- Exploring several layout directions for a new page or feature before committing engineering time.
- Producing a clickable prototype for stakeholder review (Claude artifact or v0 preview).
- Bootstrapping a screen composed of shadcn/ui primitives your repo already uses.
- Distributing your own components through a shadcn registry so generators and agents compose with them.
- Getting a first pass at marketing sections that will be heavily art-directed afterwards.

## When Not To Use
- Complex stateful flows (checkout, auth, permissions) where correctness matters more than layout; write these by hand or with a coding agent inside the repo and tests.
- Screens that must match an existing Figma spec pixel-for-pixel; use [design-to-code-figma-workflow](../design-to-code-figma-workflow/Skill.md).
- When no design tokens or component library exist yet and the generated look would silently become the design system.
- Regulated UIs (healthcare, fintech) where generated copy and patterns need domain review anyway.

## Core Principles
1. Generated UI is a draft, not a dependency. It enters the repo only through an intake step (tokens, primitives, states, a11y, tests).
2. Generate against your system, not a blank slate: feed the tool your tokens, component registry and constraints first.
3. One source of primitives. If `components/ui/button.tsx` exists, generated `<button className="...">` markup is replaced, never kept alongside.
4. The repo's framework version wins. Generated code is re-checked against installed Next.js/React docs (async `params`, Server vs Client Components, caching APIs).
5. Verify in the real app, not in the generator preview: typecheck, lint, build, browser check, axe.
6. Distinctiveness is a deliberate input; left alone, generators converge on the same look (see [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md)).

## Best Practices
- Prompt with structure: page purpose, audience, sections in order, data shape (a TypeScript type), required states, breakpoints, and "use existing shadcn components; no new colors outside tokens".
- Paste or reference your token file (Tailwind v4 `@theme` block or CSS variables) and list the installed shadcn components so the generator composes with them.
- Ask for Server Components by default and `'use client'` only on the interactive leaf, then verify this manually; generators frequently mark whole pages as client.
- Request realistic content lengths (long names, empty lists, 3-digit counts) to expose layout fragility early.
- Keep generation iterations small and scoped ("only change the pricing table") to avoid regenerating stable parts.
- Publish internal components as a shadcn registry (`components.json` `registries` with a namespace such as `@acme`) so both v0-style tools and the shadcn MCP server install your components rather than inventing new ones.
- Record prompts that produced accepted output in the PR description for reproducibility.
- Treat generated copy as placeholder; run it through microcopy review.

## Implementation Guidance

### Tool selection
| Need | Tool | Notes |
|---|---|---|
| Fast Next.js + Tailwind + shadcn screen draft | v0 | Output targets Next.js/shadcn/Tailwind; can deploy previews on Vercel. Confirm versions match your repo before copying. |
| Self-contained interactive prototype to share in chat | Claude artifact via `web-artifacts-builder` skill | Scaffolds React + TS + Vite + Tailwind + shadcn and bundles into a single inlined HTML file. Prototype only; stack differs from Next.js App Router. |
| Install real components into the repo via chat | shadcn MCP server | `npx shadcn@latest mcp init --client claude` (also cursor, vscode, codex). Browses/searches/installs from configured registries. |
| Style/palette/font-pairing ideas and UX checklists | `nextlevelbuilder/ui-ux-pro-max-skill` | Large searchable CSV knowledge base via Python search script plus npm CLI installer. Use as inspiration; see caveats below. |
| Full-app generators (Lovable, Bolt and similar) | Hosted app builders | Useful for throwaway prototypes; exported code needs the same intake. Not evaluated in depth here. |

### Intake checklist (generated code -> Next.js repo)
1. Create a branch; put generated files in a scratch location (for example `app/(sandbox)/draft/page.tsx`) first.
2. Replace raw markup with installed primitives (`Button`, `Card`, `Dialog`, `Input`, `Label`). Run `npx shadcn@latest add <component>` for missing ones instead of pasting generated copies.
3. Replace hardcoded values: hex colors, `px` spacing, arbitrary Tailwind values like `bg-[#7c3aed]` become token utilities (`bg-primary`, `text-muted-foreground`).
4. Split Server/Client: keep data fetching in the page (Server Component), move interactivity into small `'use client'` components. Await `params`/`searchParams` per installed Next.js version.
5. Replace mock data with typed props and real data access; delete generated fake fetch helpers.
6. Add states: loading (`loading.tsx` or Suspense fallback that mirrors final layout), empty, error (`error.tsx`), long content.
7. Accessibility pass: labels on every control, icon buttons with `aria-label`, no `div onClick`, visible `:focus-visible`, heading order, color not the only signal.
8. Performance pass: `next/image` with sizes, `next/font`, no giant client bundles (dynamic import heavy widgets), no `transition-all`.
9. Remove unused dependencies the generator added (icon packs, animation libs) unless approved.
10. Verify: typecheck, lint, test, build, then browser check and axe (see [frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md)).

### Registry setup so generators use your components
```json
// components.json (excerpt)
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "tailwind": { "css": "app/globals.css", "cssVariables": true },
  "aliases": { "components": "@/components", "ui": "@/components/ui" },
  "registries": {
    "@acme": "https://registry.acme.dev/r/{name}.json"
  }
}
```
Private registries should read auth tokens from environment variables, never committed values.

## Recommended Workflow
1. Write a one-paragraph brief plus a TypeScript type for the data the screen shows.
2. Generate 2–3 directions; pick one based on hierarchy and flow, not polish.
3. Iterate in the generator with scoped prompts until structure is right (ignore colors/fonts at this stage).
4. Export/copy into a sandbox route in the repo.
5. Run the intake checklist (primitives, tokens, server/client split, states, a11y, perf).
6. Apply the project's visual direction per the design brief.
7. Run the verification loop and capture screenshots at mobile and desktop widths.
8. Move from sandbox to the real route, delete scratch files, open PR with prompt notes and screenshots.

## Patterns
- **Structure-first generation**: prompt for layout and content hierarchy only, then apply tokens by hand. Avoids fighting generated styling.
- **Registry-constrained generation**: expose your components via a shadcn registry and instruct "only use @acme components"; output composes with your library.
- **Sandbox route intake**: `app/(sandbox)/...` excluded from navigation and robots until hardened, then moved.
- **Type-first prompt**:
  ```ts
  type Invoice = { id: string; customer: string; amountCents: number; currency: 'USD' | 'EUR'; status: 'paid' | 'overdue' | 'draft'; dueDate: string }
  // Prompt: "Render a responsive invoice list for Invoice[]; include empty, loading and overdue emphasis states; use Table, Badge, Button from components/ui."
  ```

## Anti-Patterns
- **Pasting whole generated pages as `'use client'`**: ships unnecessary JS and loses streaming. Fix: server page plus client leaves.
- **Duplicate primitives** (`components/generated/button.tsx` next to `components/ui/button.tsx`): drift and inconsistent focus styles. Fix: delete and use the canonical primitive.
- **Arbitrary color values everywhere**: breaks dark mode and theming. Fix: map to tokens.
- **Keeping generated mock data and fake latency** in production code. Fix: typed props and real data layer.
- **Accepting the default AI look** (centered hero, purple gradient, Inter, uniform rounded cards). Fix: apply a design brief.
- **Running a skill pack's installer or scripts without reading them**. Fix: inspect scripts, pin versions, prefer copying the knowledge you need.
- **Trusting generator preview as verification**. Fix: verify in your running app.

## Accessibility
- Generated markup commonly fails WCAG 2.2 on 1.3.1 (info and relationships: missing labels/table headers), 2.1.1 (keyboard: clickable divs), 2.4.7 (focus visible: `outline-none` without replacement), 1.4.3 (contrast of muted text on tinted backgrounds), 4.1.2 (name/role/value for icon buttons).
- Prefer shadcn/Radix primitives for dialogs, menus, tabs; they include focus management and ARIA.
- Run axe (for example `@axe-core/playwright`) on the hardened route; fix all critical/serious issues before merge. See [ai-accessibility-audit-workflow](../ai-accessibility-audit-workflow/Skill.md).

## Responsive Design
- Ask for explicit behavior at small (~375px), tablet (~768px) and desktop (~1280px+) widths; generators often design desktop-only.
- Check tables and multi-column cards for overflow on mobile; replace with stacked layouts or horizontal scroll containers with visible affordance.
- Verify inputs are at least 16px on mobile to avoid iOS zoom and that hit targets are at least 24px (44px preferred on touch).

## Performance
- Remove unused animation or icon libraries the generator imported; import icons individually.
- Replace `<img>` with `next/image` and give dimensions to prevent CLS.
- Replace Google Fonts `<link>` tags with `next/font`.
- Virtualize long generated lists; avoid `.map` over hundreds of rows in client components.

## Security
- Generated forms often post directly to placeholder endpoints or embed API keys in client code; move secrets server-side and validate inputs in Server Actions/Route Handlers.
- `dangerouslySetInnerHTML` in generated content must be removed or sanitized.
- Community skill packs and CLIs can run arbitrary code; review before installation and never grant broad permissions (see [coding-agent-security-for-frontend](../coding-agent-security-for-frontend/Skill.md)).
- Private registry tokens belong in `.env.local`/CI secrets, not `components.json`.

## Testing
- Component tests (Vitest + Testing Library) for any interactive logic introduced during intake.
- Playwright smoke test that the route renders key headings/controls and passes axe.
- Optional visual baseline with `toHaveScreenshot` once the design is approved (see [visual-regression-testing](../visual-regression-testing/Skill.md)).

## Tooling
- **v0** (Vercel): Next.js/Tailwind/shadcn-oriented generator with previews and deployment. Active.
- **shadcn CLI + MCP server**: canonical way to add components and registry items. Active.
- **Anthropic `web-artifacts-builder` skill**: React/Vite/Tailwind/shadcn artifact bundling to single HTML. Active; prototype use.
- **nextlevelbuilder/ui-ux-pro-max-skill**: very popular community skill (styles, palettes, font pairings, UX rules, stack guidelines) driven by a Python BM25 search script and an npm installer. Useful reference data; caveats: requires Python and an installer, marketing claims about a "reasoning engine" are unvalidated, premium upsell, and multi-framework guidance is generic. Rate as inspiration, not authority.
- **Lovable/Bolt-style app builders**: hosted full-app generation; evaluate exported code with the same intake.

## Framework Notes
- **Next.js App Router**: confirm generated code matches installed version (async request APIs, `use cache`/Cache Components if enabled, `proxy` vs `middleware` naming in newer releases). Point agents at `node_modules/next/dist/docs/` via AGENTS.md. Keep generated pages as Server Components.
- **React (Vite SPA)**: Claude artifacts and many generators output Vite-style React; when used in a SPA, remove Next-specific imports (`next/image`, `next/link`) or map them to your router and image strategy.

## AI Agent Guidance
- Do: read the repo's tokens, `components.json`, and installed `components/ui` before generating or integrating.
- Do: use the shadcn MCP/CLI to add components rather than writing new primitives.
- Do: run the intake checklist and report which items changed.
- Don't: introduce new dependencies, fonts or colors without stating why.
- Don't: leave generated code in place of an existing canonical component.
- Don't: execute installers or scripts from community skill packs without user approval.
- Done means: typecheck, lint, test and build pass; route renders in the browser at mobile and desktop widths; axe has no critical/serious violations; screenshots attached; scratch files removed.

## Examples
Generator prompt tuned for a Next.js repo:
```text
Build the "Team members" settings page.
Stack: Next.js App Router, TypeScript, Tailwind v4 tokens (bg-background, text-foreground, primary, muted), shadcn/ui components already installed: Button, Table, Badge, DropdownMenu, Dialog, Input, Label.
Data: type Member = { id: string; name: string; email: string; role: 'owner'|'admin'|'member'; invitedAt: string | null }
Sections: header with "Invite member" button -> table (name, email, role badge, actions menu) -> empty state.
States: loading skeleton matching table rows, empty, error message with retry.
Rules: no hex colors, no new fonts, icon buttons need aria-label, page is a Server Component; only the invite dialog and actions menu are client components.
```

Intake diff example (before -> after):
```tsx
// before (generated)
<div onClick={() => setOpen(true)} className="rounded-xl bg-[#7c3aed] px-4 py-2 text-white">Invite</div>

// after (hardened)
import { Button } from '@/components/ui/button'
<Button onClick={() => setOpen(true)}>Invite member</Button>
```

## Related Skills
- [shadcn-ui](../shadcn-ui/Skill.md) — primitives and registry the output should use
- [design-to-code-figma-workflow](../design-to-code-figma-workflow/Skill.md) — when a spec exists
- [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md) — avoid generic generated looks
- [frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md) — verifying integrated code
- [mcp-for-frontend-development](../mcp-for-frontend-development/Skill.md) — shadcn MCP setup
- [ai-frontend-code-review](../ai-frontend-code-review/Skill.md) — reviewing the intake PR
- [tailwind-design-system-architecture](../tailwind-design-system-architecture/Skill.md) — token mapping
- [coding-agent-security-for-frontend](../coding-agent-security-for-frontend/Skill.md) — vetting skill packs and installers

## Sources
- [v0 docs](https://v0.app/docs) — Official — stack targets and capabilities
- [shadcn MCP docs](https://ui.shadcn.com/docs/mcp) — Official — MCP init commands, registries config
- [anthropics/skills web-artifacts-builder](https://github.com/anthropics/skills/tree/main/skills/web-artifacts-builder) — Open Source — artifact stack, bundling, anti-slop notes
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — Community — contents, mechanism, caveats
- [Vercel Web Interface Guidelines](https://vercel.com/design/guidelines) — Official (Vercel) — hardening details
- [Next.js AI agents guide](https://nextjs.org/docs/app/guides/ai-agents) — Official — version-matched docs for agents

## License / Usage Notes
Content summarized from the sources above; no verbatim copying of skill files. anthropics/skills skills carry their own license terms (see each skill's LICENSE); ui-ux-pro-max-skill is MIT; shadcn/ui is MIT. v0 output ownership and usage are governed by Vercel's terms.

## Quality Tier
B — solid, actionable intake process grounded in official docs; generator-specific details (v0, Lovable/Bolt) are shallow and change quickly.

## Status
Active

## Last Verified
2026-09-15
