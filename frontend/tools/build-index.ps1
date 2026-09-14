# Builds INDEX.md, SOURCES.md, DUPLICATES.md from skills + manifests
$base = 'D:\skills\frontend'
$root = "$base\skills"
$today = '2026-09-15'

function Get-Tables($path, $headingRx) {
  # returns row arrays (cells) from markdown tables under headings matching $headingRx
  $rows = @(); $inSection = $false; $headerSeen = $false
  foreach ($line in Get-Content $path) {
    if ($line -match '^#{1,4}\s') { $inSection = ($line -match $headingRx); $headerSeen = $false; continue }
    if (-not $inSection) { continue }
    if ($line -match '^\s*\|') {
      if ($line -match '^\s*\|[\s:\-|]+\|\s*$') { continue }
      $cells = ($line.Trim().Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() }
      if (-not $headerSeen) { $headerSeen = $true; continue }
      $rows += ,$cells
    }
  }
  return $rows
}

# Framework + primary source hints from manifests
$fw = @{}; $prim = @{}
$manifests = Get-ChildItem "$base\_work" -Filter 'manifest-*.md'
foreach ($m in $manifests) {
  foreach ($r in (Get-Tables $m.FullName 'Skills')) {
    if ($r.Count -ge 7) { $slug = $r[0] -replace '[`\[\]]',''; $fw[$slug] = $r[3]; $prim[$slug] = $r[6] }
  }
}

$items = foreach ($d in Get-ChildItem $root -Directory) {
  $f = "$($d.FullName)\Skill.md"; if (-not (Test-Path $f)) { continue }
  $c = Get-Content $f -Raw
  $title = if ($c -match '(?m)^# (.+)$') { $Matches[1].Trim() } else { $d.Name }
  $cat = if ($c -match '## Category\s+([^\r\n]+)') { $Matches[1].Trim(' *') } else { 'Uncategorized' }
  $q = if ($c -match '## Quality Tier\s+\**\s*([SABCD])\b') { $Matches[1] } else { '?' }
  $st = if ($c -match '## Status\s+\**\s*(Active|Experimental|Stale|Deprecated|Archived)') { $Matches[1] } else { '?' }
  $src = ''
  if ($c -match '(?s)## Sources\s+(.*?)\r?\n## ') { if ($Matches[1] -match '\[([^\]]+)\]\((https?://[^)\s]+)\)') { $src = "[$($Matches[1])]($($Matches[2]))" } }
  if (-not $src -and $prim[$d.Name]) { $src = $prim[$d.Name] }
  $framework = if ($fw[$d.Name]) { $fw[$d.Name] } elseif ($cat -eq 'React') { 'React' } elseif ($cat -eq 'Next.js') { 'Next.js' } else { 'React / Next.js' }
  [pscustomobject]@{Slug=$d.Name; Title=$title; Category=$cat; Framework=$framework; Quality=$q; Status=$st; Source=$src}
}

$order = 'Architecture','Security','Tooling','React','Next.js','CSS & Styling','Components','UI Libraries','UX','Product Patterns','Accessibility','Performance','Animation','Data Visualization','Enterprise UI','Testing & QA','AI Agent Workflows'
$cats = @($order | Where-Object { $items.Category -contains $_ }) + @($items.Category | Sort-Object -Unique | Where-Object { $order -notcontains $_ })

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Frontend Skills Index (React + Next.js)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Total skills: **$($items.Count)** · Last generated: $today")
[void]$sb.AppendLine('')
$tiers = $items | Group-Object Quality | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }
[void]$sb.AppendLine("Quality distribution — $($tiers -join ' · ')")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Categories')
foreach ($cat in $cats) { $n = ($items | Where-Object Category -eq $cat).Count; $a = ($cat.ToLower() -replace '[^a-z0-9 -]','' -replace ' ','-'); [void]$sb.AppendLine("- [$cat](#$a) ($n)") }
foreach ($cat in $cats) {
  [void]$sb.AppendLine(''); [void]$sb.AppendLine("## $cat"); [void]$sb.AppendLine('')
  [void]$sb.AppendLine('| Skill | Path | Category | Framework | Quality | Status | Primary Source |')
  [void]$sb.AppendLine('|---|---|---|---|---|---|---|')
  foreach ($i in ($items | Where-Object Category -eq $cat | Sort-Object Slug)) {
    [void]$sb.AppendLine("| $($i.Title -replace '\|','/') | [skills/$($i.Slug)/Skill.md](skills/$($i.Slug)/Skill.md) | $($i.Category) | $($i.Framework -replace '\|','/') | $($i.Quality) | $($i.Status) | $($i.Source) |")
  }
}
Set-Content "$base\INDEX.md" $sb.ToString() -Encoding utf8

# SOURCES.md — dedupe by URL
$srcRows = @{}
foreach ($m in $manifests) {
  foreach ($r in (Get-Tables $m.FullName 'Sources')) {
    if ($r.Count -lt 7) { continue }
    $url = $r[1] -replace '^<|>$',''
    if ($url -match '\((https?://[^)]+)\)') { $url = $Matches[1] }
    $key = $url.TrimEnd('/').ToLower()
    if (-not $key) { continue }
    if ($srcRows.ContainsKey($key)) { $srcRows[$key].Used += ", $($m.BaseName -replace 'manifest-','')"; continue }
    $qv = $r[5].Trim(' *')
    switch -Regex ($qv) {
      '^(Very High|Highest|Exceptional)' { $qv = 'S'; break }
      '^High'   { $qv = 'A'; break }
      '^Medium' { $qv = 'B'; break }
      '^Low'    { $qv = 'C'; break }
      '^(Rejected|Poor|Very Low)' { $qv = 'D'; break }
      '^([SABCD])\b' { $qv = $Matches[1]; break }
    }
    $srcRows[$key] = [pscustomobject]@{Source=$r[0]; Url=$url; Type=$r[2]; Extracted=$r[3]; Why=$r[4]; Quality=$qv; Verified=$r[6]; Used=($m.BaseName -replace 'manifest-','')}
  }
}
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Source Registry'); [void]$sb.AppendLine('')
[void]$sb.AppendLine("Unique sources: **$($srcRows.Count)** (deduplicated by URL across all workstreams) · Last generated: $today"); [void]$sb.AppendLine('')
[void]$sb.AppendLine('Workstream codes: W01 Architecture/Security · W02 React · W03 Next.js · W04 React/Next stack extensions · W05 CSS · W06 Overlay/Nav components · W07 Form components · W08 UI libraries · W09 UX · W10 Product patterns · W11 Accessibility · W12 Performance · W13 Animation · W14 Data viz · W15 Enterprise UI · W16 Testing · W17 AI agent workflows · W18 MCP catalog · G* gap passes'); [void]$sb.AppendLine('')
[void]$sb.AppendLine('| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified | Used By |')
[void]$sb.AppendLine('|---|---|---|---|---|---|---|---|')
foreach ($s in ($srcRows.Values | Sort-Object Type, Source)) {
  [void]$sb.AppendLine("| $($s.Source) | $($s.Url) | $($s.Type) | $($s.Extracted) | $($s.Why) | $($s.Quality) | $($s.Verified) | $($s.Used) |")
}
Set-Content "$base\SOURCES.md" $sb.ToString() -Encoding utf8

# DUPLICATES.md
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Duplicates & Overlaps'); [void]$sb.AppendLine('')
[void]$sb.AppendLine('Overlapping knowledge found across sources and skills, the canonical source chosen, and where it was merged. Last generated: ' + $today); [void]$sb.AppendLine('')
[void]$sb.AppendLine('| Topic | Canonical Source | Alternates Merged | Merged Into Slug | Workstream |')
[void]$sb.AppendLine('|---|---|---|---|---|')
$dupCount = 0
foreach ($m in $manifests) {
  foreach ($r in (Get-Tables $m.FullName 'Duplicat')) {
    if ($r.Count -lt 4) { continue }
    $dupCount++
    [void]$sb.AppendLine("| $($r[0]) | $($r[1]) | $($r[2]) | $($r[3]) | $($m.BaseName -replace 'manifest-','') |")
  }
}
Set-Content "$base\DUPLICATES.md" $sb.ToString() -Encoding utf8
# CATEGORIES.md — taxonomy with descriptions and grouped skills
$desc = @{
  'Architecture'       = 'App structure, component APIs, design systems & tokens, monorepos, micro-frontends, state/API/error architecture, i18n, flags, observability, TypeScript.'
  'Security'           = 'XSS/CSP, token handling, supply chain, env/config security for React + Next.js.'
  'Tooling'            = 'Build tooling, linting/formatting, project setup.'
  'React'              = 'React 19 model: composition, hooks, rendering, Server Components, state, data fetching, Suspense, Actions, compiler, routing alternatives, stack extensions.'
  'Next.js'            = 'Next.js 16 App Router: routing, RSC, Server Actions, caching, rendering, proxy, metadata, images/fonts, auth, deployment, performance, migrations, content.'
  'CSS & Styling'      = 'Modern CSS, Tailwind v4, CSS architecture, layout, responsive design, typography, color, theming, dark mode, RTL.'
  'Components'         = 'Accessible, production-grade component patterns: overlays, navigation, display, inputs, forms.'
  'UI Libraries'       = 'Engineering evaluation of React component ecosystems: shadcn/ui, Radix, Base UI, React Aria, MUI, Mantine, etc.'
  'UX'                 = 'UX foundations: hierarchy, IA, flows, states (empty/loading/error), microcopy, heuristics, optimistic UI, auth UX, AI chat UX, ethics.'
  'Product Patterns'   = 'Patterns per product type: landing pages, SaaS, ecommerce, checkout, marketplaces, docs, dev tools, fintech, healthcare, mobile web/PWA, SEO, payments, email.'
  'Accessibility'      = 'WCAG 2.2, ARIA, semantics, keyboard, focus, screen readers, contrast, motion, tables, media, live regions, SPA routing, testing, legal.'
  'Performance'        = 'Core Web Vitals (LCP/INP/CLS), bundles, splitting, images, fonts, hydration, rendering, memory, network, caching, offline, profiling, RUM.'
  'Animation'          = 'Motion for React, GSAP, CSS animation, View Transitions, scroll-driven animation, micro-interactions, layout animation, 3D.'
  'Data Visualization' = 'Visualization principles, chart selection, D3/Recharts/Chart.js/ECharts/Nivo/visx, dashboards, realtime, maps, accessible charts, large datasets.'
  'Enterprise UI'      = 'Admin panels, data grids/tables, filtering, bulk actions, RBAC UI, audit logs, workflows, ERP/CRM/WMS, multi-tenant, power-user UI, collaboration.'
  'Testing & QA'       = 'Testing strategy, Vitest/Jest, Testing Library, Playwright/Cypress, visual regression, Storybook, MSW, Lighthouse CI, CI/CD, flake management.'
  'AI Agent Workflows' = 'Agent skills/rules authoring (Claude Code, Cursor, Copilot, AGENTS.md), design-to-code, browser-MCP loops, AI a11y audits, debugging, review, verification.'
}
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Category Taxonomy (React + Next.js)'); [void]$sb.AppendLine('')
[void]$sb.AppendLine("Complete taxonomy of the library: $($cats.Count) categories, $($items.Count) skills. Each skill lives at ``skills/<slug>/Skill.md``. Last generated: $today"); [void]$sb.AppendLine('')
[void]$sb.AppendLine('| Category | Skills | Scope |'); [void]$sb.AppendLine('|---|---|---|')
foreach ($cat in $cats) { [void]$sb.AppendLine("| $cat | $(($items | Where-Object Category -eq $cat).Count) | $($desc[$cat]) |") }
foreach ($cat in $cats) {
  [void]$sb.AppendLine(''); [void]$sb.AppendLine("## $cat"); [void]$sb.AppendLine('')
  if ($desc[$cat]) { [void]$sb.AppendLine("_$($desc[$cat])_"); [void]$sb.AppendLine('') }
  foreach ($i in ($items | Where-Object Category -eq $cat | Sort-Object Slug)) {
    $sub = ''
    $c = Get-Content "$root\$($i.Slug)\Skill.md" -Raw
    if ($c -match '## Subcategories\s+([^\r\n]+)') { $sub = " — $($Matches[1].Trim())" }
    [void]$sb.AppendLine("- [$($i.Slug)](skills/$($i.Slug)/Skill.md) ($($i.Quality))$sub")
  }
}
Set-Content "$base\CATEGORIES.md" $sb.ToString() -Encoding utf8

"Index: $($items.Count) skills; Sources: $($srcRows.Count); Duplicate rows: $dupCount"
