# Documentation Site Patterns

## Summary
How to structure, build, and operate product and developer documentation sites on Next.js: content architecture using the Diátaxis framework (tutorials, how-to guides, reference, explanation), page anatomy, navigation and search, versioning, API reference generation from OpenAPI, code sample UX, feedback loops, and AI/agent readability (llms.txt, Markdown endpoints). Primary tooling is Fumadocs or Nextra on the App Router, or custom MDX.

## Category
Product Patterns

## Subcategories
Diátaxis, docs information architecture, MDX, API reference, OpenAPI, versioning, docs search, code blocks, llms.txt, docs-as-code

## Problem It Solves
Docs sites mix tutorials, reference, and conceptual essays on the same page, so no reader is served well. Search returns nothing useful and code samples are broken or can't be copied. Versions diverge silently, and API reference drifts from the actual API. AI assistants and coding agents also increasingly read docs and struggle with HTML-heavy, JS-rendered pages. This skill provides structure, templates, and a Next.js implementation path.

## When To Use
- Building a public product/developer docs portal, SDK docs, API reference, or internal engineering handbook.
- Migrating docs to Next.js (from GitBook, ReadMe, Docusaurus, or a wiki).
- Adding versioning, OpenAPI reference, or AI-readable exports.

## When Not To Use
- Blog/editorial content: [content-and-blog-sites](../content-and-blog-sites/Skill.md).
- In-app contextual help and onboarding tours: [onboarding-ux](../onboarding-ux/Skill.md).
- Component library workshops (Storybook): [storybook-component-workshop](../storybook-component-workshop/Skill.md).

## Core Principles
1. **Separate the four documentation modes (Diátaxis).** Tutorials are learning-oriented, how-to guides are goal-oriented, reference is information-oriented, and explanation is understanding-oriented. Each page serves one mode.
2. **Docs are code.** Content lives in the repo, gets reviewed in PRs, is tested (links, code samples, types), and deploys with CI.
3. **Reference is generated, not hand-written.** API and CLI reference come from OpenAPI, TypeScript types, or CLI definitions, so they can't drift.
4. **Search is the primary navigation.** Many readers arrive from search engines or site search, so every page must stand alone with context and prerequisites.
5. **Copy-paste must work.** Samples are complete, tested, and never contain real secrets.
6. **Readable by humans and machines.** Serve semantic, server-rendered HTML plus clean Markdown for agents (`/llms.txt`, per-page `.md`).

## Best Practices

### Information architecture
- Top-level tabs or sections: **Get started** (quickstart tutorial) · **Guides** (how-to) · **Concepts** (explanation) · **API Reference** · **SDKs/CLI** · **Changelog**.
- The quickstart reaches a meaningful result in under about 10 minutes: prerequisites, install, configure, first successful call, next steps.
- How-to titles start with a verb and a goal: "Rotate API keys", "Handle webhooks retries".
- Reference pages have a consistent structure per entity: description, parameters table, return type, errors, example request/response.
- Put glossary and troubleshooting pages in the navigation.

### Page anatomy
1. Breadcrumbs + title + one-sentence description (also used as meta description).
2. Prerequisites / "Before you begin" (for tutorials and how-tos).
3. Body with H2/H3 steps; numbered steps for procedures.
4. Code blocks with language tabs (curl/TypeScript/Python), filename labels, copy button, highlighted lines.
5. Callouts: Note, Warning, and Danger used sparingly and consistently.
6. "Next steps" links.
7. Footer: "Was this page helpful?" feedback, edit-on-GitHub link, last updated date.
8. Right rail: on-this-page table of contents (H2/H3), scroll-spy highlight.

### Code sample UX
- Language switcher persists choice site-wide (localStorage) and syncs all tab groups on the page.
- Placeholders are visually distinct and explained: `YOUR_API_KEY`, or inject the signed-in user's test key client-side only with explicit opt-in. Never server-render real keys into cached HTML.
- Show expected output after commands.
- Line wrapping off by default with horizontal scroll; ensure focusable scroll region.

### Versioning
- Version only when breaking changes create materially different usage (major versions). Use a version selector in the header.
- URL scheme: `/docs/v2/...` for old versions, unversioned `/docs/...` for latest. Old versions carry a banner ("You're viewing v2 docs. See latest") and a canonical to latest where content is equivalent.

### Search
- Full-text search with keyboard shortcut (`/` or Cmd/Ctrl+K), grouped results (Guides, Reference), highlighted matches, recent searches.
- Log zero-result queries and treat them as a content backlog.
- AI "Ask docs" answers must cite source pages and be clearly labelled as AI-generated.

## Implementation Guidance

### Tool decision table (Next.js)
| Option | Fit | Notes |
|--------|-----|-------|
| **Fumadocs** | Most flexible Next.js docs framework; React components; OpenAPI integration; LLM helpers | Content via Fumadocs MDX or other sources; also runs on other React frameworks |
| **Nextra 4** | Fast setup, opinionated theme, App Router only | Built-in search; good for smaller docs |
| **Custom MDX** (`@next/mdx`, Velite/Content Collections) | Full control inside an existing Next.js app | You build nav, search, TOC |
| Hosted platforms (Mintlify, ReadMe, GitBook) | No frontend ownership | Less control; lock-in; still apply Diátaxis |

Docusaurus is a mature React-based alternative outside Next.js and is out of scope as a primary choice here.

### Folder structure (Fumadocs-style)
```
content/docs/
  index.mdx                      # Overview
  get-started/quickstart.mdx     # Tutorial
  guides/rotate-api-keys.mdx     # How-to
  concepts/authentication.mdx    # Explanation
  api/                           # Generated from openapi.yaml
  meta.json                      # Sidebar order and section titles
app/docs/[[...slug]]/page.tsx    # Renders pages from source loader
app/llms.txt/route.ts            # AI index
app/docs-md/[...slug]/route.ts   # Markdown per page (or content negotiation in proxy)
```

### Frontmatter contract
```yaml
---
title: Rotate API keys
description: Replace an API key without downtime using overlapping key validity.
type: how-to            # tutorial | how-to | reference | explanation
lastReviewed: 2026-09-01
---
```
Lint in CI so every page declares `type` and `description`.

### llms.txt route
```ts
// app/llms.txt/route.ts
import { source } from "@/lib/source"; // docs source loader

export const dynamic = "force-static";

export function GET() {
  const pages = source.getPages();
  const body = [
    "# Acme Docs",
    "> Acme is an API for reconciling payments. These docs cover setup, guides, concepts, and API reference.",
    "",
    "## Docs",
    ...pages.map(p => `- [${p.data.title}](https://acme.dev${p.url}.md): ${p.data.description ?? ""}`),
  ].join("\n");
  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
```

## Recommended Workflow
1. Audit existing content; tag each page with its Diátaxis type; split mixed pages.
2. Define IA (sections/tabs) and URL scheme; write the quickstart first.
3. Scaffold Fumadocs/Nextra or MDX pipeline; implement page anatomy components (callout, tabs, steps, code block).
4. Generate API reference from OpenAPI in CI; fail build on spec validation errors.
5. Add search, feedback widget, edit links, last-updated.
6. Add SEO (metadata, sitemap.ts, canonical for versions) and AI-readability (llms.txt, `.md` pages).
7. Add CI checks: broken links, MDX compile, code samples type-check/run, spelling/prose lint (Vale), accessibility scan.
8. Operate: review zero-result searches and low-helpfulness pages monthly.

## Patterns
- **Steps component:** ordered list with numbered headings; each step's code block follows its instruction.
- **Synced language tabs:** a `CodeGroup` keyed by `lang` sharing state via context + localStorage.
- **API endpoint page:** method badge + path, auth, params table (name, type, required, description), request example tabs, response example with status tabs, error codes table, "Try it" playground (optional).
- **Version banner** for non-latest versions.
- **Copy page as Markdown / Open in AI assistant** action in the page header.
- **Changelog** with dated entries, tags (Added/Changed/Deprecated/Removed/Fixed/Security), RSS feed.

## Anti-Patterns
- **Tutorial that becomes a reference dump halfway through.** Fix: link to reference; keep the tutorial linear.
- **Hand-written API reference.** It drifts. Fix: generate from OpenAPI/types; test examples.
- **Client-rendered docs content.** Poor indexing and agent readability. Fix: static generation of MDX pages.
- **Screenshots of code.** Can't be copied and inaccessible. Fix: text code blocks.
- **Real keys or tokens in samples, even "test" ones.** They leak into search indexes and caches. Fix: placeholders; client-side opt-in injection.
- **Versioning every minor release.** Maintenance explosion. Fix: version only majors; annotate "Added in 2.3" inline.
- **Search that only matches titles.** Fix: full-text with headings and anchors.

## Accessibility
- Code blocks: horizontally scrollable regions need `tabIndex={0}` and an accessible name. Syntax highlight colors meet 4.5:1 in both themes.
- Copy buttons: labelled ("Copy code"), with success announced via live region ("Copied").
- Tabs follow the ARIA tabs pattern, or use simple buttons with `aria-pressed` if they change all groups.
- Callouts: don't rely on color/icon alone; include a text label ("Warning:").
- TOC scroll-spy must not steal focus; `aria-current="true"` on the active item.
- Search dialog: accessible combobox/listbox pattern; Escape closes; focus returns.
- Diagrams need text alternatives or accompanying prose.

## Responsive Design
- Three-column desktop (sidebar · content · TOC) → two-column tablet (TOC collapses into a "On this page" disclosure) → single column mobile (sidebar in drawer).
- Content max-width about 70–80ch for prose; code blocks may extend wider.
- Tables: wrap in a horizontally scrollable, focusable container on small screens.

## Performance
- Statically generate all docs pages; search index built at build time (Orama/Flexsearch local index, or Algolia DocSearch crawler).
- Syntax highlighting at build/server time (Shiki), not client-side.
- Lazy-load heavy components (API playground, diagrams) with `next/dynamic`.
- Keep per-page JS small; docs pages should be mostly server-rendered HTML.

## Security
- API playground: never proxy arbitrary requests through your server (SSRF). Call the real API from the browser with the user's own credentials, or use a sandbox.
- MDX from untrusted contributors can execute code at build. Require review for MDX changes; avoid rendering user-submitted MDX at runtime.
- Secret scanning in CI on docs content.
- Feedback forms: rate-limit, bot protection, no PII required.

## Testing
- CI: MDX compile, link checker (internal + external with allowlist), OpenAPI lint (Spectral/Redocly CLI).
- Code samples: extract and type-check TypeScript snippets; run shell snippets against a sandbox in nightly jobs.
- Visual regression for page anatomy components in light/dark.
- axe scan on representative pages; keyboard test of search and nav.
- Verify `/llms.txt` and `.md` routes return 200 with expected content.

## Tooling
- Docs frameworks: Fumadocs (active, Next.js-first), Nextra 4 (App Router only).
- Highlighting: Shiki. Prose lint: Vale. Link check: lychee or linkinator.
- Search: Orama (local, OSS), Algolia DocSearch (free for OSS docs), Pagefind (static index), Typesense.
- API reference: Fumadocs OpenAPI, Scalar, Redocly; spec lint with Spectral.
- AI readability: llms.txt conventions (supported by Fumadocs helpers, Mintlify, and plugins across ecosystems).

## Framework Notes
- **Next.js App Router (primary):**
  - `app/docs/[[...slug]]/page.tsx` with `generateStaticParams` from the content source.
  - `generateMetadata` from frontmatter (title template `%s | Acme Docs`, description, canonical for versions).
  - `app/sitemap.ts` lists all docs pages; versioned-old pages optionally excluded.
  - `notFound()` for unknown slugs so they return a real 404.
  - Route Handlers for `/llms.txt`, `/llms-full.txt`, per-page Markdown. Optionally, `proxy.ts` rewrites requests with `Accept: text/markdown` to the Markdown route.
  - MDX components mapped via `mdx-components.tsx`. Keep them Server Components unless interactive (tabs, copy button).
- **React (Vite SPA):** avoid for public docs (SEO, agent readability). Acceptable for internal authenticated handbooks; still prerender if possible.

## AI Agent Guidance
- Classify each page you write with a Diátaxis type, and don't mix modes.
- Generate reference from source (OpenAPI/types) instead of writing it by hand.
- Test every code sample you add, or mark it untested and flag it.
- Never include real keys, tokens, internal URLs, or customer data in examples.
- Verify before done:
  - [ ] Page has title, description, type frontmatter; appears in nav and sitemap
  - [ ] Code blocks copyable, labelled, and highlighted server-side
  - [ ] Internal links pass link checker
  - [ ] Page renders statically; `/llms.txt` includes it
  - [ ] Keyboard and screen reader work for tabs, copy, and search

## Examples

```tsx
// components/copy-button.tsx — accessible copy with announcement
"use client";
import { useState } from "react";

export function CopyButton({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <>
      <button type="button" aria-label="Copy code" onClick={async () => {
        await navigator.clipboard.writeText(code);
        setCopied(true); setTimeout(() => setCopied(false), 2000);
      }}>{copied ? "Copied" : "Copy"}</button>
      <span role="status" className="sr-only">{copied ? "Code copied to clipboard" : ""}</span>
    </>
  );
}
```

~~~mdx
<Steps>
### Install the SDK
```bash
npm install @acme/sdk
```

### Create a client
```ts title="lib/acme.ts"
import { Acme } from "@acme/sdk";
export const acme = new Acme({ apiKey: process.env.ACME_API_KEY! });
```
</Steps>
~~~

## Related Skills
- [content-and-blog-sites](../content-and-blog-sites/Skill.md) — shared MDX/content pipeline
- [developer-tool-ui-patterns](../developer-tool-ui-patterns/Skill.md) — API consoles, keys, playgrounds
- [seo-for-frontend](../seo-for-frontend/Skill.md) — metadata, sitemaps, canonicals
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — docs search UI
- [command-palette](../command-palette/Skill.md) — Cmd+K search patterns
- [tabs](../tabs/Skill.md) — language tabs
- [nextjs-metadata-and-seo](../nextjs-metadata-and-seo/Skill.md) — metadata API
- [information-architecture](../information-architecture/Skill.md) — IA methods
- [agents-md-conventions](../agents-md-conventions/Skill.md) — machine-readable guidance for agents

## Sources
- [Diátaxis](https://diataxis.fr/) — Official (framework) — four documentation types and their user needs
- [Fumadocs docs](https://www.fumadocs.dev/docs) — Open Source — framework layers, MDX source, OpenAPI, LLM integration
- [Nextra docs](https://nextra.site/docs) — Open Source — Nextra 4 App Router-only, search, page map
- [Mintlify — llms.txt](https://www.mintlify.com/docs/ai/llmstxt) — Community/vendor — llms.txt and Markdown content negotiation for agents
- [Google Search Central — JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics) — Official — server-rendered, crawlable content
- [Next.js docs — metadata files and generateStaticParams](https://nextjs.org/docs/app/api-reference/file-conventions/metadata) — Official — sitemap/robots/metadata conventions

## License / Usage Notes
Diátaxis is published under CC BY-SA 4.0; concepts summarized with attribution, text not copied. Fumadocs and Nextra are MIT-licensed. Code examples are original.

## Quality Tier
A — Grounded in the widely adopted Diátaxis framework and official tool docs; llms.txt is a community convention, not a formal standard, so that portion is less settled.

## Status
Active

## Last Verified
2026-09-15
