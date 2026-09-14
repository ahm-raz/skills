# Design System Governance

## Summary
The operating model that keeps a design system useful: team models (centralized, federated, hybrid), contribution workflows, decision rights, versioning and deprecation policy, quality gates, adoption metrics, and communication. Draws heavily on Nathan Curtis/EightShapes' published models and adapts them to a React/Next.js component library delivered via npm packages or a shadcn-style registry.

## Category
Architecture

## Subcategories
Team models, contribution model, RFC process, versioning policy, deprecation, adoption metrics, component lifecycle, design-engineering handoff

## Problem It Solves
Design systems fail socially more often than technically: the core team becomes a bottleneck, product teams fork or ignore components, breaking changes land without warning, and nobody knows whether a component is safe to use. Governance defines who decides, how changes enter, and how consumers stay current.

## When To Use
- A design system is consumed by more than one team or app.
- Product teams complain about waiting for the system team, or the system team complains about snowflake forks.
- Planning a major version or rebrand.

## When Not To Use
- A single team owning both app and components: a lightweight PR review is enough; don't create committees.
- Before the system has real consumers — governance without adoption is bureaucracy.

## Core Principles
1. **The system is a product with customers** (product teams); measure adoption and satisfaction.
2. **Explicit decision rights.** Who approves new components, token changes, and breaking changes is written down.
3. **Multiple contribution paths sized to the change** — a typo fix and a new data grid need different processes (Curtis: optimize multiple contribution models, not one perfect one).
4. **Predictable change.** Semver, release cadence, deprecation windows, codemods, and changelogs.
5. **Transparent status.** Every component labeled (Alpha/Beta/Stable/Deprecated) in docs and code.
6. **Enable local solutions without forks.** Composition and extension points reduce pressure to fork; snowflakes are allowed but tracked.

## Best Practices
- Choose and document a team model (EightShapes' framing):
  | Model | Description | Works when | Risk |
  |---|---|---|---|
  | Solitary/Overlord | One team builds for itself, others adopt ad hoc | Early stage | Not representative of other products |
  | Centralized | Dedicated system team builds and distributes | Many consumers, funding available | Bottleneck, disconnected from product reality |
  | Federated | Designers/devs from product teams contribute part-time | Mature org, strong culture | Slow decisions, uneven quality |
  | Hybrid (cyclical) | Small core team + federated contributors | Most mid/large orgs | Needs clear contribution process |
- Define contribution sizes: **Fix** (bug/typo — PR directly), **Enhancement** (new variant/prop — issue + design review + PR), **New component/pattern** (RFC + proposal review + pairing with core team), **Breaking change** (RFC + migration plan + codemod).
- Use an RFC template in the repo (`rfcs/0000-template.md`) with problem, evidence of need (at least 2 products), API proposal, a11y plan, alternatives.
- Adopt a "snowflake -> candidate -> system" path: teams build locally, register in a catalog, promote when reused.
- Publish a support policy: current major fully supported; previous major gets security/critical fixes for N months.
- Deprecation: mark `@deprecated` JSDoc + dev console warning + docs banner + codemod; remove no sooner than next major and at least one release cycle later.
- Run office hours and a public roadmap; announce releases in changelog + chat channel.
- Track metrics: component adoption per app (AST scan), version lag, detached/overridden instances in Figma, a11y defects, contribution lead time, consumer satisfaction survey.
- Define "definition of done" for Stable: tokens only, a11y audit (keyboard + screen reader), stories for all states, visual tests, docs with do/don't, types exported, RSC compatibility verified (Next.js).

## Implementation Guidance

### Decision-rights matrix (RACI-lite)
| Change | Proposes | Reviews | Approves | Informed |
|---|---|---|---|---|
| Bug fix | Anyone | Core engineer | Core engineer | Changelog |
| New variant/prop | Anyone | Core design + eng | Core lead | Changelog |
| New component | Contributor via RFC | Design council + a11y | System lead | Roadmap, release notes |
| Token change (semantic) | Designer | Brand + a11y (contrast) | Design lead | All consumers |
| Breaking change | Core team | Consumer reps | System lead | Migration guide + codemod |

### Repository scaffolding
```
.github/
  ISSUE_TEMPLATE/bug.yml, enhancement.yml, new-component.yml
  PULL_REQUEST_TEMPLATE.md      (checklist: tokens, a11y, stories, changeset, docs)
  CODEOWNERS                    (/packages/tokens/ @acme/ds-design; /packages/react/ @acme/ds-eng)
rfcs/
  0000-template.md
  0012-data-table.md
.changeset/
docs/governance.md              (models, decision rights, support policy)
```

### Component status in code and docs
```ts
// packages/react/src/meta.ts
export const componentStatus = {
  Button: 'stable',
  DataTable: 'beta',
  LegacyModal: 'deprecated',
} as const satisfies Record<string, 'alpha' | 'beta' | 'stable' | 'deprecated'>;
```
```tsx
// Dev-only deprecation warning
/** @deprecated Use <Dialog> from '@acme/ds-react/dialog'. Removal in v7. */
export function LegacyModal(props: LegacyModalProps) {
  if (process.env.NODE_ENV !== 'production') {
    console.warn('[acme-ds] LegacyModal is deprecated; run `npx @acme/ds-codemods v7/legacy-modal`.');
  }
  return <Dialog {...mapLegacyProps(props)} />;
}
```

### Adoption scanning (React)
- `react-scanner` or a custom ts-morph/ast-grep script counting JSX imports from `@acme/ds-react` vs local `components/ui/Button` duplicates.
- Report per repo: version in lockfile, usage counts, deprecated component usage, raw color literals (stylelint report).

### PR template checklist
```md
- [ ] Uses semantic tokens only (no raw values)
- [ ] Keyboard + screen reader verified (NVDA/VoiceOver notes)
- [ ] Stories for all variants/states; visual snapshots updated
- [ ] Works as Server Component or has 'use client' in the right module
- [ ] Changeset added (patch/minor/major) with migration notes if major
- [ ] Docs: usage, do/don't, props table
```

## Recommended Workflow
1. Interview consumer teams; map pain points and current forks.
2. Pick team model and write `docs/governance.md` (decision rights, support policy).
3. Add issue/PR/RFC templates and CODEOWNERS.
4. Define component lifecycle statuses and Stable definition of done.
5. Stand up adoption scanning and publish a dashboard.
6. Run a contribution pilot with one product team; measure lead time.
7. Review governance quarterly; adjust contribution sizes and SLAs.

## Patterns
- **RFC for new components**, lightweight PRs for fixes.
- **Contribution pairing:** core member pairs with contributor for first contribution.
- **Snowflake registry:** local components catalogued with owner and reuse count; promotion when 2+ products use them.
- **Release trains:** minors every 2 weeks, majors at most twice a year with codemods.
- **Design council:** rotating product designers + a11y specialist reviewing proposals weekly.
- **Registry recipes (shadcn-style) for patterns**, versioned packages for primitives — different governance weight for each.

## Anti-Patterns
- **Core team as gatekeeper for everything** — teams fork. Fix: tiered contribution paths with SLAs.
- **Breaking changes in minors** — trust collapses. Fix: semver discipline, API Extractor reports in CI.
- **Deprecate and delete in the same release** — Fix: deprecation window + codemod.
- **No consumer representation** in decisions — Fix: consumer reps in breaking-change reviews.
- **Measuring success by component count** — Fix: adoption, version lag, defect rates.
- **Figma and code governed separately** — drift. Fix: single change process touching both, token sync automation.
- **Forbidding all local components** — unrealistic. Fix: allow snowflakes, track and promote.

## Accessibility
- Accessibility sign-off is a governance gate for Stable (WCAG 2.2 AA); include an a11y specialist in approval rights.
- Track a11y bugs against the system separately and prioritize them above features.
- Document known limitations per component publicly.

## Responsive Design
- Governance should require responsive/container behavior documentation and stories at multiple container widths for layout-affecting components.

## Performance
- Add bundle-size budgets per component to the definition of done (size-limit in CI); new dependencies require review.

## Security
- CODEOWNERS on package publishing workflows; trusted publishing with provenance; require 2FA for maintainers.
- Dependency additions to the system require review (the system is in every app's supply chain).

## Testing
- Governance gates enforced in CI: lint (tokens), type/API report diff, unit/interaction tests, axe on stories, visual regression, size-limit.
- Consumer smoke tests: build a sample Next.js app and Vite app against release candidates.

## Tooling
- Changesets — Active (versioning, changelogs).
- API Extractor — Active (public API diff for breaking-change detection).
- react-scanner / ast-grep / ts-morph — Active (adoption scanning).
- Storybook docs + status badges — Active.
- zeroheight / Supernova / Knapsack — Commercial documentation platforms (evaluate).
- GitHub CODEOWNERS, issue forms — Active.

## Framework Notes
- **React (Vite SPA):** consumers upgrade via package manager; provide codemods (jscodeshift/ast-grep) targeting TSX.
- **Next.js:** add RSC compatibility to the definition of done; release candidates tested in a Next.js App Router canary app (streaming, Server Components importing display components, `'use client'` boundaries preserved).
- **shadcn-style registries:** governance shifts to "upstream diffing" — publish changelogs per registry item and a CLI diff command so consumers can pull fixes into copied code.

## AI Agent Guidance
- Before adding or changing a design-system component, read `docs/governance.md` and the RFC list; determine contribution size.
- Do: add a changeset, update stories/docs, respect component status (don't build on Alpha for production features without flagging).
- Don't: introduce breaking prop changes without deprecation aliases and a codemod; don't copy a system component locally to tweak it — propose a variant or use composition.
- Verify: PR checklist items satisfied, API report diff reviewed, deprecated usages not increased.

## Examples
```md
<!-- rfcs/0000-template.md -->
# RFC: <Component/Change>
### Problem & evidence (which products, links to screens)
### Proposed API (TSX usage examples)
### Accessibility plan (APG pattern, keyboard map)
### Tokens needed
### Alternatives considered (existing components, composition)
### Migration / rollout (if breaking)
### Open questions
```
```yaml
# .github/ISSUE_TEMPLATE/new-component.yml
name: New component proposal
labels: [rfc, needs-triage]
body:
  - type: textarea
    id: need
    attributes: { label: "Which products need this and why?" }
    validations: { required: true }
  - type: textarea
    id: existing
    attributes: { label: "Why can't existing components/composition solve it?" }
```

## Related Skills
- [design-system-architecture](../design-system-architecture/Skill.md) — technical structure being governed
- [design-token-architecture](../design-token-architecture/Skill.md) — token change process
- [component-api-design](../component-api-design/Skill.md) — API review criteria
- [storybook-component-workshop](../storybook-component-workshop/Skill.md) — docs and review surface
- [visual-regression-testing](../visual-regression-testing/Skill.md) — quality gates
- [shadcn-ui](../shadcn-ui/Skill.md) — registry-based distribution

## Sources
- [EightShapes: Team Models for Scaling a Design System](https://medium.com/eightshapes-llc/team-models-for-scaling-a-design-system-2cf9d03be6a0) — Community (respected) — solitary/centralized/federated models
- [EightShapes: Defining Design System Contributions](https://eightshapes.com/articles/defining-contributions/) — Community — contribution sizes
- [EightShapes: Contributions to Design Systems](https://medium.com/eightshapes-llc/contributions-to-design-systems-89261a9363d8) — Community — multiple contribution models
- [Changesets](https://github.com/changesets/changesets) — Open Source — versioning workflow
- [API Extractor](https://api-extractor.com/) — Open Source — API reports

## License / Usage Notes
EightShapes articles are copyrighted; models are paraphrased with attribution, not copied. Tools are MIT.

## Quality Tier
A — built on widely cited practitioner frameworks plus concrete repo tooling; governance is organizational, so effectiveness varies by context.

## Status
Active

## Last Verified
2026-09-15
