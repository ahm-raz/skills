# Manifest W18: MCP Catalog

Output: `D:\skills\frontend\MCP_CATALOG.md` | Last Verified: 2026-09-15

Method: GitHub REST API (`/repos/OWNER/REPO`: license, pushed_at, archived, stars) for about 50 repos, until the unauthenticated rate limit ran out. After that: GitHub repo pages and vendor docs via WebFetch, and official MCP Registry search (`registry.modelcontextprotocol.io/v0/servers?search=`). No servers were installed or run. WebSearch was not used.

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| GitHub REST API (batch) | https://api.github.com/repos/{owner}/{repo} | API | License SPDX, pushed_at, archived flag, stars, redirects (renames) for ~50 repos | Objective maintenance and license data; found renames (supabase-community→supabase/mcp, stripe/agent-toolkit→stripe/ai, addon-mcp→storybookjs/mcp) and archives | A | 2026-09-15 |
| MCP reference servers README | https://raw.githubusercontent.com/modelcontextprotocol/servers/main/README.md | Primary repo | Current reference list (everything, fetch, filesystem, git, memory, sequential-thinking, time), license (Apache-2.0 new / MIT existing), npx/uvx commands | Baseline reference servers | A | 2026-09-15 |
| servers-archived | https://github.com/modelcontextprotocol/servers-archived | Primary repo | Archived 2025-05-29; list (GitHub, GitLab, Postgres, Puppeteer, Slack, GDrive, Sentry...); "NO SECURITY GUARANTEES" | AVOID section | A | 2026-09-15 |
| Playwright MCP | https://github.com/microsoft/playwright-mcp | Primary repo | Config, flags (--isolated, --allowed-origins, --caps, --extension), "not a security boundary" | CORE browser server | A | 2026-09-15 |
| Chrome DevTools MCP | https://github.com/ChromeDevTools/chrome-devtools-mcp | Primary repo | Config, flags (--slim, --isolated, --autoConnect, --no-usage-statistics), telemetry, Windows SystemRoot | CORE debugging/perf | A | 2026-09-15 |
| Playwright Test Agents | https://playwright.dev/docs/test-agents | Vendor docs | planner/generator/healer, `init-agents --loop=claude` | QA stack | A | 2026-09-15 |
| GitHub MCP Server | https://github.com/github/github-mcp-server | Primary repo | Remote URL, toolsets, PAT vs OAuth | CORE dev server | A | 2026-09-15 |
| GitLab MCP docs | https://docs.gitlab.com/user/model_context_protocol/mcp_server/ | Vendor docs | Beta since 18.6, `/api/v4/mcp`, OAuth DCR, all tiers | GitLab users | A | 2026-09-15 |
| Context7 | https://github.com/upstash/context7 | Primary repo | Remote URL, tools, API key, community-docs disclaimer, MIT client / proprietary backend | CORE docs | A | 2026-09-15 |
| DeepWiki MCP | https://docs.devin.ai/work-with-devin/deepwiki-mcp | Vendor docs | URL, no auth, tools, SSE deprecated | Repo docs | A | 2026-09-15 |
| Ref | https://github.com/ref-tools/ref-tools-mcp | Primary repo | HTTP endpoint, tools, MIT | Docs alternative | B | 2026-09-15 |
| Microsoft Learn MCP | https://github.com/MicrosoftDocs/mcp | Primary repo | URL, no auth, tools, dual license | Docs | A | 2026-09-15 |
| next-devtools-mcp | https://github.com/vercel/next-devtools-mcp | Primary repo | Tools (nextjs_index/call/docs, browser_eval), Next 16+, Node 20.19+, MIT, Windows env note | CORE Next.js | A | 2026-09-15 |
| Vercel MCP docs | https://vercel.com/docs/mcp/vercel-mcp | Vendor docs | `https://mcp.vercel.com`, OAuth, approved clients, security best practices | CORE deploy | A | 2026-09-15 |
| shadcn MCP docs | https://ui.shadcn.com/docs/mcp | Vendor docs | `shadcn mcp init`, config, registries | CORE components | A | 2026-09-15 |
| Figma MCP docs + guide | https://developers.figma.com/docs/figma-mcp-server/ ; https://github.com/figma/mcp-server-guide | Vendor docs/repo | Remote/desktop URLs, tools, seat rate limits, catalog-only clients | Design-to-code | A | 2026-09-15 |
| Framelink | https://github.com/GLips/Figma-Context-MCP | Community repo | Config, Windows `cmd /c`, PAT, MIT | Figma fallback | A | 2026-09-15 |
| Storybook MCP | https://github.com/storybookjs/mcp ; https://github.com/storybookjs/storybook/tree/next/code/addons/mcp | Primary repo | Archived 2026-09-07, moved to monorepo v10.6; addon install, /mcp endpoint | Component knowledge | A | 2026-09-15 |
| Chromatic MCP docs | https://www.chromatic.com/docs/mcp/ | Vendor docs | Published `<appid>.chromatic.com/mcp`, OAuth, Storybook 10.3+ React | Visual QA | A | 2026-09-15 |
| Argos MCP docs | https://argos-ci.com/docs/agents/mcp-server.md | Vendor docs | `https://mcp.argos-ci.com`, OAuth/PAT, scopes, tools | Visual QA | A | 2026-09-15 |
| Penpot MCP | https://github.com/penpot/penpot-mcp | Primary repo | Archived 2026-02-03 → penpot/penpot/mcp; install; arbitrary code execution in plugin | Open-source design | B | 2026-09-15 |
| Canva Dev MCP | https://www.canva.dev/docs/apps/mcp-server/ | Vendor docs | `npx @canva/cli@latest mcp`, scope (Canva app devs) | Design (niche) | B | 2026-09-15 |
| 21st.dev Magic | https://github.com/21st-dev/magic-mcp | Primary repo | Rebrand to 21st MCP, key reset, HTTP URL, tool renames | Component gen | B | 2026-09-15 |
| Magic UI MCP | https://github.com/magicuidesign/mcp | Primary repo | CLI install, tools, MIT | Components | B | 2026-09-15 |
| Browserbase MCP | https://github.com/browserbase/mcp-server-browserbase | Primary repo | Archived; hosted `mcp.browserbase.com/mcp`; env vars; tools | Cloud browser | B | 2026-09-15 |
| Stagehand | https://github.com/browserbase/stagehand | Primary repo | SDK (MIT), not an MCP server itself | Dedupe | B | 2026-09-15 |
| Browser Use MCP docs | https://docs.browser-use.com/customize/integrations/mcp-server | Vendor docs | `uvx --from 'browser-use[cli]' browser-use --mcp`, tools, requires LLM key | Agentic browser | B | 2026-09-15 |
| BrowserMCP | https://github.com/BrowserMCP/mcp | Primary repo | Last push 2025-04-24, not buildable standalone, closed extension, real profile | AVOID rationale | B | 2026-09-15 |
| Serena | https://github.com/oraios/serena | Primary repo | uv install, LSP backends, MIT + GPL-3.0-or-later | Code intelligence | A | 2026-09-15 |
| Desktop Commander | https://github.com/wonderwhy-er/DesktopCommanderMCP | Community repo | Tools, "not a sandbox", telemetry opt-out, Docker isolation | Shell risk | B | 2026-09-15 |
| Supabase MCP docs | https://supabase.com/docs/guides/getting-started/mcp | Vendor docs | `mcp.supabase.com/mcp`, project_ref, read_only, features, prompt injection warning | Backend | A | 2026-09-15 |
| Neon MCP | https://github.com/neondatabase/mcp-server-neon | Primary repo | `mcp.neon.tech/mcp`, OAuth/API key, readonly, dev-only warning | Backend | A | 2026-09-15 |
| Firebase MCP docs | https://firebase.google.com/docs/ai-assistance/mcp-server | Vendor docs | `npx firebase-tools@latest mcp`, --only, --dir | Backend | A | 2026-09-15 |
| Prisma MCP docs | https://www.prisma.io/docs/postgres/integrations/mcp-server | Vendor docs | `npx prisma mcp`, `mcp.prisma.io/mcp`, tool categories, destructive guardrails | ORM | A | 2026-09-15 |
| MongoDB MCP | https://github.com/mongodb-js/mongodb-mcp-server | Primary repo | env vars, --readOnly, --indexCheck, Node 22.13+ | Backend | A | 2026-09-15 |
| Apollo MCP | https://github.com/apollographql/apollo-mcp-server | Primary repo | GraphQL ops as tools, Rust binary/Docker/rover, MIT | GraphQL | A | 2026-09-15 |
| Postgres MCP Pro | https://github.com/crystaldba/postgres-mcp | Community repo | API metadata (MIT, 2026-08-17) | Replaces archived postgres ref | B | 2026-09-15 |
| OpenAPI MCP Server | https://github.com/ivo-toby/mcp-openapi-server | Community repo | env vars, tool filtering, MIT, 293 stars | REST-to-MCP | C | 2026-09-15 |
| Stripe MCP docs | https://docs.stripe.com/mcp | Vendor docs | `mcp.stripe.com`, OAuth / restricted keys, tools, human confirmation for writes | Payments | A | 2026-09-15 |
| Clerk MCP docs | https://clerk.com/docs/guides/ai/mcp/clerk-mcp-server | Vendor docs | `mcp.clerk.com/mcp`, snippet tools, beta | Auth | B | 2026-09-15 |
| Auth0 MCP | https://github.com/auth0/auth0-mcp-server | Primary repo | init, device flow + keychain, --read-only, --tools, beta | Auth | B | 2026-09-15 |
| WorkOS MCP docs | https://workos.com/docs/mcp | Vendor docs | `mcp.workos.com/mcp`, OAuth, intentional exclusions | Auth | B | 2026-09-15 |
| Convex MCP docs | https://docs.convex.dev/ai/convex-mcp-server | Vendor docs | `npx convex mcp start`, prod flags, deploy key scoping | Backend | A | 2026-09-15 |
| Upstash MCP | https://github.com/upstash/mcp-server | Primary repo | CLI args, capabilities, MIT | Redis/QStash | B | 2026-09-15 |
| Netlify MCP | https://github.com/netlify/netlify-mcp | Primary repo | `npx -y @netlify/mcp`, CLI auth / PAT, Node 22+ | Deploy | A | 2026-09-15 |
| Cloudflare MCP | https://github.com/cloudflare/mcp-server-cloudflare | Primary repo | 15 remote server URLs, code-mode `mcp.cloudflare.com/mcp`, Apache-2.0 | Edge deploy | A | 2026-09-15 |
| awslabs/mcp | https://github.com/awslabs/mcp | Primary repo | AWS MCP (managed), Knowledge, Docs, Serverless, IaC; Cloud Control deprecated | Cloud | A | 2026-09-15 |
| microsoft/mcp | https://github.com/microsoft/mcp | Primary repo | Catalog incl. Azure MCP, MIT | Cloud | A | 2026-09-15 |
| Cloud Run MCP | https://github.com/GoogleCloudPlatform/cloud-run-mcp | Primary repo | npx package, gcloud ADC, tools | Cloud | B | 2026-09-15 |
| Docker MCP Gateway | https://github.com/docker/mcp-gateway | Primary repo | Container isolation, secrets, `docker mcp client connect claude-code` | Isolation | A | 2026-09-15 |
| Docker Hub MCP | https://github.com/docker/hub-mcp | Primary repo | Tools, HUB_PAT_TOKEN, Apache-2.0 | Images | B | 2026-09-15 |
| Railway MCP | https://github.com/railwayapp/railway-mcp-server | Primary repo | Archived → `railway mcp` in CLI; `--remote` | Deploy | B | 2026-09-15 |
| Render MCP | https://github.com/render-oss/render-mcp-server | Primary repo | Tools, API key, read-only DB queries, no direct service updates | Deploy | B | 2026-09-15 |
| Sentry MCP | https://github.com/getsentry/sentry-mcp ; LICENSE.md | Primary repo | `mcp.sentry.dev`, stdio flags, scopes, FSL-1.1-Apache-2.0, LLM provider env | Observability | A | 2026-09-15 |
| PostHog MCP | https://github.com/PostHog/mcp ; https://posthog.com/docs/model-context-protocol | Repo + docs | Archived → monorepo; `mcp.posthog.com/mcp`, wizard, API key preset / OAuth | Analytics | A | 2026-09-15 |
| Datadog MCP docs | https://docs.datadoghq.com/bits_ai/mcp_server/ | Vendor docs | Toolsets, fair-use limits, audit trail | Observability | A | 2026-09-15 |
| BrowserStack MCP | https://github.com/browserstack/mcp-server | Primary repo | 45 tools, remote `mcp.browserstack.com/mcp`, AGPL-3.0 | Cross-browser/a11y | A | 2026-09-15 |
| Lighthouse MCP | https://github.com/danielsogl/lighthouse-mcp-server | Community repo | npx package, tools, Node 22+, MIT, 71 stars | Perf audits | C | 2026-09-15 |
| MCP Accessibility Scanner | https://github.com/JustasMonkev/mcp-accessibility-scanner | Community repo | axe-core tools, WCAG tags, MIT, 56 stars | a11y | C | 2026-09-15 |
| Notion MCP docs | https://developers.notion.com/docs/mcp | Vendor docs | Remote hosted, OAuth, capabilities | Productivity | A | 2026-09-15 |
| Linear MCP docs | https://linear.app/docs/mcp | Vendor docs | `mcp.linear.app/mcp`, `/readonly`, OAuth/API key | Productivity | A | 2026-09-15 |
| Atlassian MCP | https://github.com/atlassian/atlassian-mcp-server | Primary repo | `mcp.atlassian.com/v2/mcp`, v1 sunset 2026-06-30, admin controls | Productivity | A | 2026-09-15 |
| mcp-atlassian | https://github.com/sooperset/mcp-atlassian | Community repo | API metadata (MIT, active, 5.9k stars) | Self-hosted Jira | B | 2026-09-15 |
| Slack MCP docs | https://docs.slack.dev/ai/mcp-server/ | Vendor docs | `mcp.slack.com/mcp`, OAuth, admin approval, partner clients | Productivity | A | 2026-09-15 |
| korotovsky slack-mcp-server | https://github.com/korotovsky/slack-mcp-server | Community repo | API metadata; "no permission requirements" claim | Risk note | C | 2026-09-15 |
| Asana MCP docs | https://developers.asana.com/docs/using-asanas-mcp-server | Vendor docs | V2 `mcp.asana.com/v2/mcp`, V1 SSE shutdown 2026-05-11 | Productivity | B | 2026-09-15 |
| Cloudinary MCP | https://github.com/cloudinary/mcp-servers | Primary repo | 5 servers, remote/local/docker, env vars | Assets | B | 2026-09-15 |
| Unsplash community MCPs | https://github.com/hellokaton/unsplash-mcp-server ; registry search | Community | Python server, UNSPLASH_ACCESS_KEY, MIT; hanoak alt | Stock images | C | 2026-09-15 |
| svgicons.com MCP | https://github.com/svgicons-com/mcp | Small vendor repo | Remote URL, Iconify sets, Pro tier, MIT, 0 stars | Icons | C | 2026-09-15 |
| Sanity MCP docs | https://www.sanity.io/docs/compute-and-ai/mcp-server | Vendor docs | `mcp.sanity.io`, OAuth, `sanity mcp configure`, tools; local repo archived | CMS | A | 2026-09-15 |
| Contentful MCP | https://github.com/contentful/contentful-mcp-server | Primary repo | env vars, PROTECTED_ENVIRONMENTS, MIT | CMS | A | 2026-09-15 |
| MCP Registry searches | https://registry.modelcontextprotocol.io/v0/servers?search= (storyblok, builder, strapi, lokalise, crowdin, icon, chromatic, argos, axe, image, token, drizzle, unsplash, lucide) | Registry API | Presence/absence of official servers | Gap detection | B | 2026-09-15 |
| Google Workspace CLI | https://github.com/googleworkspace/cli | Repo | "not an officially supported Google product", no MCP mode documented | Google Drive gap | B | 2026-09-15 |

## Duplicates

| Overlapping / fork / legacy | Canonical |
|---|---|
| `modelcontextprotocol/servers-archived` → `src/github` (`@modelcontextprotocol/server-github`) | `github/github-mcp-server` (remote `api.githubcopilot.com/mcp/`) |
| servers-archived `gitlab` | GitLab built-in MCP (`/api/v4/mcp`) |
| servers-archived `postgres` | Neon / Supabase MCP (hosted PG) or `crystaldba/postgres-mcp` |
| servers-archived `puppeteer` | `ChromeDevTools/chrome-devtools-mcp` (Puppeteer-based) or `microsoft/playwright-mcp` |
| servers-archived `slack` ; `korotovsky/slack-mcp-server` | Official Slack MCP `mcp.slack.com/mcp` |
| servers-archived `sentry` | `getsentry/sentry-mcp` (`mcp.sentry.dev`) |
| servers-archived `gdrive` | Claude.ai Google Drive connector (client feature, not an MCP server entry) / gap |
| `storybookjs/addon-mcp` → `storybookjs/mcp` (archived) | `@storybook/addon-mcp` in `storybookjs/storybook` |
| Chromatic published MCP | Same `@storybook/addon-mcp`, hosted by Chromatic |
| `penpot/penpot-mcp` (archived) | `penpot/penpot` `/mcp` |
| `supabase-community/supabase-mcp` (redirect) | `supabase/mcp` / `mcp.supabase.com/mcp` |
| `stripe/agent-toolkit` (redirect), `@stripe/mcp` local | `stripe/ai` / `mcp.stripe.com` |
| `browserbase/mcp-server-browserbase` (archived) ; Stagehand | Hosted `mcp.browserbase.com/mcp`; Stagehand is the SDK underneath |
| `@railway/mcp-server` / `railwayapp/railway-mcp-server` (archived) | `railway mcp` (Railway CLI) |
| `PostHog/mcp` (archived) | `PostHog/posthog/services/mcp` / `mcp.posthog.com/mcp` |
| `sanity-io/sanity-mcp-server` (archived) | `mcp.sanity.io` |
| `@21st-dev/magic` (Magic MCP) | 21st MCP `https://21st.dev/api/mcp` |
| `makenotion/notion-mcp-server` (local) | Notion hosted remote MCP (OAuth) |
| `sooperset/mcp-atlassian` | Atlassian Rovo MCP `mcp.atlassian.com/v2/mcp` (community one for Server/DC) |
| Asana V1 `mcp.asana.com/sse` | Asana V2 `mcp.asana.com/v2/mcp` |
| Magic UI MCP | shadcn MCP + Magic UI registry (overlap) |
| Context7 / Ref / DeepWiki / MS Learn | Context7 (general libs) canonical; others complementary |
| Lighthouse MCP | Chrome DevTools MCP perf traces (overlap); BrowserStack a11y (overlap with axe scanner) |
| `azure/azure-mcp` | `microsoft/mcp` (Azure MCP Server) |
| Cloudflare domain-specific servers | `cloudflare/mcp` code-mode server (broad API) |

## Gaps

- **Design tokens:** no verified dedicated MCP (Tokens Studio, Style Dictionary, Supernova, Specify).
- **Drizzle ORM:** no official or registry-listed MCP found.
- **Storyblok, Lokalise, official Crowdin:** docs/repo guesses returned 404 and the registry had no official entries. Crowdin has only a third-party `io.usefulapi/crowdin`.
- **Strapi:** only community registry entries (AINative-Studio, PaulRichez). No official Strapi MCP verified.
- **Builder.io:** only "Agent-Native" MCPs (analytics, assets, brain...) in the registry. No verified Builder CMS/Visual Editor or Fusion MCP.
- **Iconify / Lucide:** no official MCP. Only svgicons.com (new, 0 stars). Lucide registry search was empty.
- **Image generation:** no verified vendor-official MCP relevant to frontend (registry is full of small or unknown publishers).
- **Deque axe official MCP:** guessed repo returned 404, so it is unverified. Community axe-core scanner used instead.
- **Sourcegraph MCP:** docs returned 403, so it is unverified.
- **Google Drive:** reference server archived. Google Workspace CLI is explicitly not official and has no documented MCP mode. No verified official Drive MCP server.
- **Canva AI connector (end-user):** help page returned 403. Only Canva Dev MCP verified.
- **Unauthenticated GitHub API limit (60/hr)** stopped metadata checks for docker/hub-mcp, browserbase/stagehand, and shadcn-ui/ui; their metadata comes from repo pages instead. Stars and `pushed_at` for Lighthouse, a11y scanner, Unsplash, and OpenAPI MCP come from page scrapes, not the API.
- **Licenses without SPDX in the API:** vercel/next-devtools-mcp (README says MIT), netlify/netlify-mcp (none detected), vercel/mcp-handler (none detected), figma/mcp-server-guide. Check the LICENSE files directly before redistributing.
- **No hands-on testing:** the Windows `cmd /c` need is taken from vendor docs (Framelink, Claude Code conventions) and was not reproduced.
