# Consistency audit for D:\skills\frontend\skills
$root = 'D:\skills\frontend\skills'
$required = @('## Summary','## Category','## Subcategories','## Problem It Solves','## When To Use','## When Not To Use',
  '## Core Principles','## Best Practices','## Implementation Guidance','## Recommended Workflow','## Patterns',
  '## Anti-Patterns','## Accessibility','## Responsive Design','## Performance','## Security','## Testing','## Tooling',
  '## Framework Notes','## AI Agent Guidance','## Examples','## Related Skills','## Sources','## License / Usage Notes',
  '## Quality Tier','## Status','## Last Verified')
$secretRx = '(sk_live_[0-9A-Za-z]{10,}|sk-[A-Za-z0-9]{32,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
$scopeRx = '\b(Vue|Nuxt|Angular|Svelte|SvelteKit|SolidJS|Qwik|Astro)\b'
$slugs = (Get-ChildItem $root -Directory).Name
$issues = @()
foreach ($s in $slugs) {
  $f = Join-Path $root "$s\Skill.md"
  if ($s -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $issues += [pscustomobject]@{Slug=$s; Issue='non-kebab slug'} }
  $extra = Get-ChildItem (Join-Path $root $s) | Where-Object Name -ne 'Skill.md'
  if ($extra) { $issues += [pscustomobject]@{Slug=$s; Issue="extra files: $($extra.Name -join ',')"} }
  if (-not (Test-Path $f)) { $issues += [pscustomobject]@{Slug=$s; Issue='missing Skill.md'}; continue }
  $c = Get-Content $f -Raw
  $lines = ($c -split "`n").Count
  if ($lines -lt 100) { $issues += [pscustomobject]@{Slug=$s; Issue="short ($lines lines)"} }
  $pos = -1
  foreach ($h in $required) {
    $m = [regex]::Match($c, "(?m)^$([regex]::Escape($h))\s*$")
    if (-not $m.Success) { $issues += [pscustomobject]@{Slug=$s; Issue="missing heading $h"} }
    elseif ($m.Index -lt $pos) { $issues += [pscustomobject]@{Slug=$s; Issue="out of order $h"} }
    else { $pos = $m.Index }
  }
  if ($c -notmatch '(?m)^# \S') { $issues += [pscustomobject]@{Slug=$s; Issue='missing H1'} }
  if ($c -notmatch '## Quality Tier\s+\**\s*[SABCD]\b') { $issues += [pscustomobject]@{Slug=$s; Issue='bad quality tier'} }
  if ($c -notmatch '## Status\s+\**\s*(Active|Experimental|Stale|Deprecated|Archived)') { $issues += [pscustomobject]@{Slug=$s; Issue='bad status'} }
  if ($c -notmatch '## Last Verified\s+\**\s*\d{4}-\d{2}-\d{2}') { $issues += [pscustomobject]@{Slug=$s; Issue='bad last verified'} }
  foreach ($m in [regex]::Matches($c, '\.\./([a-z0-9-]+)/Skill\.md')) {
    if ($slugs -notcontains $m.Groups[1].Value) { $issues += [pscustomobject]@{Slug=$s; Issue="broken link -> $($m.Groups[1].Value)"} }
  }
  if ($c -match $secretRx) { $issues += [pscustomobject]@{Slug=$s; Issue="POSSIBLE SECRET: $($Matches[1].Substring(0,8))..."} }
  $sc = ([regex]::Matches($c, $scopeRx)).Count
  if ($sc -gt 3) { $issues += [pscustomobject]@{Slug=$s; Issue="out-of-scope framework mentions: $sc"} }
}
"Skills: $($slugs.Count)"
"Issues: $($issues.Count)"
$issues | Sort-Object Issue, Slug | Format-Table -AutoSize | Out-String -Width 250
