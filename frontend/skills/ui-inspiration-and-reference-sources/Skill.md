# UI Inspiration and Reference Sources

## Summary
A practical guide to where to look for UI/UX references, what each source is actually good for, how reliable it is (shipped product vs. concept art), and the licensing and ethical limits of using what you find. Also covers building a team reference library and giving AI agents references without copying proprietary designs.

## Category
UX

## Subcategories
pattern libraries, design system galleries, app screenshot libraries, flow recordings, award sites, Figma Community, component galleries, licensing, moodboards, competitive analysis

## Problem It Solves
Engineers and agents either reinvent patterns from scratch or copy whatever looks trendy on Dribbble (often unshippable concept art), sometimes infringing copyrights or license terms. Choosing the right source for the question (a flow? a component? a visual direction?) saves time and produces validated patterns.

## When To Use
- Starting a new screen/flow and wanting proven patterns.
- Competitive analysis; exploring visual direction; preparing a moodboard.
- Providing reference material to an AI UI generation workflow.

## When Not To Use
- As a substitute for user research or your design system's rules.
- To clone a competitor's UI or brand assets.

## Core Principles
1. **Match source to question**: flows -> recorded real-product flows; components -> design system galleries; visual direction -> curated sites; behavior/accessibility -> design system docs.
2. **Prefer shipped, validated products** over concept shots for interaction patterns.
3. **Extract principles, not pixels**: note why a pattern works, then apply your system's tokens and components.
4. **Respect licenses and terms**: screenshots belong to their owners; library subscriptions often restrict commercial reuse of assets.
5. **Cross-check with authoritative guidance** (NN/g, Baymard, GOV.UK, platform HIGs) before adopting.
6. **Look at multiple references** (3-5) to avoid copying one product's idiosyncrasies.
7. **Accessibility isn't visible in screenshots** — verify behavior in the source design system docs.

## Best Practices
- Keep a team reference board (FigJam/Notion) with: screenshot link (not rehosted copies where terms forbid), source, pattern name, why it's good, caveats.
- For each reference, note the context: platform, audience, density, brand constraints.
- Use design system docs (Polaris, Carbon, GOV.UK, Atlassian, Material, Fluent, Primer, Spectrum) for behavior and a11y specifics.
- Treat Dribbble/Behance as visual mood only; many shots ignore real content, states, and accessibility.
- When giving references to AI agents, describe the pattern in words and link public docs; avoid feeding copyrighted screenshots with instructions to replicate.
- Re-verify license terms before any commercial use of downloaded assets (they change).

## Implementation Guidance

Source map (verify current terms before relying on any license detail):

| Source | Best for | Reliability | Licensing / caveats |
|---|---|---|---|
| Mobbin | Large library of real iOS/Android/web app screens and flows, searchable by pattern | High (shipped apps) | Paid tiers; terms grant personal, non-commercial transitory use of materials; screenshots are third parties' IP; don't rehost or rebuild the library |
| Page Flows | Video recordings of full user flows (onboarding, checkout, cancellation) | High | Subscription; recordings of third-party products; reference only |
| Component Gallery (component.gallery) | How many design systems implement a given component, with links to docs | High (links to official docs) | Free index; underlying docs belong to each system |
| Design Systems Surf / design system galleries | Browsing foundations and components of top design systems | High | Links/screens of third-party systems; check each system's license (e.g., Carbon Apache-2.0, Primer MIT, GOV.UK MIT code + OGL content) |
| Awwwards | Cutting-edge marketing/brand sites, motion, WebGL | Medium for UX (optimizes for wow) | Showcased sites are owned by their creators; performance/a11y often poor |
| Godly | Curated modern web design (marketing sites), often with video previews | Medium | Reference only |
| Land-book | Landing pages filterable by industry/style | Medium | Reference only |
| Dribbble | Visual exploration, illustration, icon styles, concept UI | Low for interaction (concept shots) | Work owned by designers; hire or license, don't copy |
| Behance | Case studies with process | Low-Medium | Owned by creators |
| Figma Community | Free UI kits, templates, icon sets, plugins | Varies | Free files are generally published under CC BY 4.0 (attribution required, commercial OK); some creators add licenses; paid resources use Figma's paid resource license — check each file |
| SaaS-focused galleries (e.g., SaaSUI, SaaSFrame, Saaspo, Refero) | App screens and SaaS marketing pages by type | Medium-High | Subscription/reference; third-party IP |
| shadcn/ui blocks, Tailwind Plus, AI Elements | Implementable React blocks | High for code | shadcn/ui and AI Elements MIT (open code); Tailwind Plus is a paid commercial license with redistribution limits |
| Laws of UX, NN/g, Baymard, GOV.UK | Principles and evidence | High (authoritative) | NN/g/Baymard articles copyrighted (cite, don't copy); Baymard full research paid; GOV.UK OGL |
| deceptive.design | What NOT to do | High | Reference/citation |
| Apple HIG, Material 3, Fluent 2 | Platform conventions | High (official) | Guidance docs; platform assets (SF Symbols, Material Symbols) have their own licenses |

Question -> source decision table:

| Question | Go to |
|---|---|
| "How do good apps do cancellation / onboarding / checkout?" | Page Flows, Mobbin (flows), Baymard for evidence |
| "What should a combobox/date picker support?" | Component Gallery -> design system docs -> WAI-ARIA APG |
| "Visual direction for a marketing site" | Godly, Land-book, Awwwards (then check perf/a11y) |
| "Dense data table UX" | Carbon, Atlassian, Polaris, AG Grid demos, Mobbin web |
| "AI chat patterns" | shapeof.ai, AI Elements examples, vendor HIGs |
| "Is this pattern manipulative?" | deceptive.design, regulator guidance |
| "Icon set to use" | Lucide/Heroicons/Phosphor/Material Symbols (check license) |

## Recommended Workflow
1. Write the design question precisely (pattern, platform, audience).
2. Pull 3-5 references from the appropriate sources.
3. Annotate: what works, why (principle), what doesn't fit your context.
4. Check authoritative guidance/research for the pattern.
5. Sketch with your own design system components and tokens.
6. Verify states, accessibility and content with real data — things screenshots never show.
7. Record the reference and rationale in the PR/design doc.

## Patterns
- **Pattern swipe file**: board columns by pattern (Empty states, Filters, Onboarding) with source links + notes.
- **Competitive teardown**: step-by-step flow screenshots from your own accounts (internal use), annotated friction points.
- **Principle extraction note**: "Reference X uses inline plan comparison near CTA -> principle: reduce uncertainty at commitment point."
- **Agent brief from references**: textual pattern description + design tokens + component list, not "make it look like [brand]".

## Anti-Patterns
- **Pixel-cloning a competitor** — IP/trade dress risk and a UI that doesn't fit your system. Fix: extract principles.
- **Building from Dribbble concept shots** — missing states, unreadable contrast, fake data. Fix: validate with shipped references and design system docs.
- **Rehosting paid-library screenshots in public docs/repos** — terms violation. Fix: link, or capture your own screenshots of products you use, for internal analysis.
- **Using Figma Community files without attribution / ignoring added licenses** — Fix: check file license; keep attribution record.
- **Chasing award-site aesthetics for app UI** — hurts usability and performance. Fix: app UI references from app libraries.
- **Single-reference design** — copies quirks. Fix: 3-5 references.

## Accessibility
- Screenshots can't show focus order, keyboard behavior, or screen reader output; confirm with WAI-ARIA APG and the source design system's accessibility docs.
- Check contrast of referenced color schemes before adopting (many showcase sites fail 1.4.3).

## Responsive Design
- Look for references on the same form factor you're designing for; mobile app patterns (bottom sheets, tab bars) don't always transfer to desktop web, and vice versa.

## Performance
- Award-winning sites often rely on heavy WebGL/video; budget and test before emulating.

## Security
- Don't upload proprietary/unreleased product screenshots or customer data to third-party inspiration tools or AI services without approval.

## Testing
- Validate adopted patterns with usability tests on your users; references are hypotheses.

## Tooling
- FigJam/Miro/Notion for boards; Eagle or similar local asset managers; browser screenshot tools; Figma Community (check licenses); AI UI tools (v0 etc.) for exploration with licensing awareness.

## Framework Notes
- **React (Vite SPA)** and **Next.js (App Router)**: implement references with your existing component library (shadcn/ui, Radix, React Aria); when using copy-paste code blocks (shadcn blocks, AI Elements), keep license notices where required and adapt to your tokens. Next.js-specific references: Vercel templates and Next.js examples repo (MIT) show routing/loading/error patterns in working code.

## AI Agent Guidance
- Do: ask or infer the design question; cite public authoritative sources; translate references into tokens/components; note license constraints when suggesting assets.
- Don't: reproduce a specific company's proprietary UI or brand; don't copy screenshots/assets from paid libraries into the repo; don't treat concept shots as validated patterns.
- Verify: final UI uses project design system; states and accessibility verified independently of the reference.

## Examples
```md
<!-- Reference note template (docs/design-references/filters.md) -->
## Pattern: Applied filter chips with "Clear all"
Sources: Component Gallery "Chip" entries (links), Carbon filtering docs (link), Mobbin web app flows (link, internal viewing only)
Why it works: recognition over recall (applied filters visible), quick recovery from zero results
Adapt: use our Tag component, max 1 row + "+3 more" overflow, keyboard removal via Backspace on focused chip
Caveats: one reference auto-applies on change; our dataset is slow -> use "Apply" button on mobile
```

## Related Skills
- [ai-ui-generation-tools](../ai-ui-generation-tools/Skill.md) — using references with AI generators
- [distinctive-frontend-design-for-agents](../distinctive-frontend-design-for-agents/Skill.md) — avoiding generic output
- [design-to-code-figma-workflow](../design-to-code-figma-workflow/Skill.md) — Figma sources to code
- [shadcn-ui](../shadcn-ui/Skill.md) — implementable blocks
- [tailwind-component-kits](../tailwind-component-kits/Skill.md) — commercial kits and licenses
- [ethical-design-and-dark-patterns](../ethical-design-and-dark-patterns/Skill.md) — deceptive.design
- [usability-heuristics](../usability-heuristics/Skill.md) — evaluating references critically

## Sources
- [Mobbin Terms of Service](https://mobbin.com/terms) — Community (commercial service) — license scope (personal, non-commercial transitory use), third-party IP
- [Page Flows](https://pageflows.com/) — Community (commercial) — flow recordings
- [The Component Gallery](https://component.gallery/) — Community — component index linking design systems
- [Design Systems Surf](https://designsystems.surf/) — Community — design system gallery
- [Figma: Community copyright and licensing](https://help.figma.com/hc/en-us/articles/360042296374-Figma-Community-copyright-and-licensing) — Official — CC BY 4.0 for free files; additional licenses
- [Figma Community Free Resource License](https://www.figma.com/legal/community-free-resource-license/) — Official
- [Awwwards](https://www.awwwards.com/), [Godly](https://godly.website/), [Land-book](https://land-book.com/), [Dribbble](https://dribbble.com/) — Community — inspiration showcases
- [shapeof.ai](https://www.shapeof.ai/) — Community — AI UX pattern library
- [SaaSUI: best SaaS UI inspiration sites compared](https://www.saasui.design/best-saas-ui-design-inspiration) — Community — source comparison

## License / Usage Notes
This skill describes sources; no screenshots or proprietary content reproduced. License details summarized from public terms as of verification date and may change — re-check before commercial use. Not legal advice.

## Quality Tier
B — useful, current landscape map; license terms for several sites were not individually verified in full and change frequently.

## Status
Active

## Last Verified
2026-09-15
