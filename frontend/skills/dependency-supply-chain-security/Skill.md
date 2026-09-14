# Dependency and Supply Chain Security

## Summary
Protecting React/Next.js projects from malicious or vulnerable npm dependencies and compromised build/publish pipelines. Reflects the 2025–2026 threat landscape (Shai-Hulud self-replicating worm: 796 packages; Mini Shai-Hulud across npm/PyPI/Packagist) and the resulting defaults: pnpm 11 `minimumReleaseAge` (1 day default) and build-script allowlists, npm v12 install-time controls (lifecycle scripts off by default, git/remote deps blocked — announced July 2026), npm trusted publishing (OIDC) and 2FA-bypass token restrictions, and OWASP Top 10:2025 A03 Software Supply Chain Failures.

## Category
Security

## Subcategories
Lockfiles, install scripts, release cooldowns, vulnerability scanning, malware detection, trusted publishing, provenance, SBOM, third-party scripts, CI secrets, dependency updates

## Problem It Solves
A typical Next.js app has 1,000+ transitive packages, each able to run code at install time, at build time, or in users' browsers. Attackers compromise maintainer tokens and publish malicious versions that steal CI secrets and cloud credentials within hours. Layered controls reduce exposure windows and blast radius.

## When To Use
- Every JavaScript project; mandatory for anything with production credentials in CI.
- Publishing packages (design systems, SDKs).
- Setting up Renovate/Dependabot, CI pipelines, or developer onboarding.

## When Not To Use
- Not a replacement for application security (XSS, auth) — see frontend-security-fundamentals.

## Core Principles
1. **Deterministic installs:** committed lockfile, frozen installs in CI.
2. **Don't run untrusted install scripts:** allowlist packages that genuinely need build scripts.
3. **Delay adoption of brand-new versions** (cooldown) — most malicious releases are detected within hours/days.
4. **Least privilege for CI and publishing:** no long-lived tokens; OIDC trusted publishing; scoped, short-lived secrets.
5. **Continuously scan** for known vulnerabilities and malware signals; triage by reachability.
6. **Minimize dependencies,** especially in client bundles and build tooling.
7. **Assume compromise is possible:** isolate secrets from install steps; be able to rotate fast.

## Best Practices
- Package manager hardening:
  | Control | pnpm 11 | npm (v11/v12) | Yarn/Bun |
  |---|---|---|---|
  | Block lifecycle scripts by default | Default (allowlist via `allowBuilds`) | v12: `allowScripts` default off; v11: `ignore-scripts=true` in `.npmrc` | Bun: trustedDependencies; Yarn: `enableScripts: false` |
  | Release age cooldown | `minimumReleaseAge: 1440` default (minutes) | Use Renovate/Dependabot cooldown; check npm `min-release-age` support for your version | Bun `minimumReleaseAge` (verify) |
  | Block git/tarball transitive deps | `blockExoticSubdeps: true` | v12: `--allow-git`/`--allow-remote` default `none` | — |
  | Trust downgrade detection | `trustPolicy: no-downgrade` | — | — |
- Always `pnpm install --frozen-lockfile` / `npm ci` in CI.
- Renovate/Dependabot with cooldown and grouping; auto-merge only patch updates of well-tested dev deps after cooldown + green CI.
- npm publishing (for your packages): trusted publishing via OIDC from GitHub Actions/GitLab/CircleCI (npm CLI ≥ 11.5.1, Node ≥ 22.14), automatic provenance (GitHub/GitLab), then set "Require 2FA and disallow tokens". Classic tokens were revoked in late 2025; 2FA-bypass granular tokens lost sensitive-operation bypass in Aug 2026 and lose direct publish around Jan 2027 (staged publish + human 2FA approval).
- CI: separate install from secret-bearing steps; don't expose deploy/cloud secrets to `install` or PR builds from forks; pin third-party GitHub Actions by commit SHA; set `permissions:` minimal per job.
- Scanning: `pnpm audit`/`npm audit` for known CVEs (noisy), plus OSV-Scanner or GitHub Dependabot alerts; malware/behavior detection with Socket, Snyk, or Aikido-style tools on PRs.
- Review new dependencies: maintainers, download trends, install scripts, publish recency, provenance, bundle size (bundlephobia/pkg-size), license.
- Client-side third-party scripts (analytics, chat widgets) are supply chain too: load via CSP-allowed origins, SRI for static versioned files, and minimize.
- Generate SBOMs (CycloneDX via `@cyclonedx/cyclonedx-npm` or `pnpm sbom` if available) for compliance.
- Developer machines: same `.npmrc`/`pnpm-workspace.yaml` settings apply locally; use Corepack or `packageManager` field to pin package manager version.

## Implementation Guidance

### pnpm 11 workspace hardening
```yaml
# pnpm-workspace.yaml
packages: ["apps/*", "packages/*"]
minimumReleaseAge: 1440            # 1 day (default in v11); consider 10080 (7 days) for critical apps
minimumReleaseAgeExclude:
  - "@acme/*"                      # your own packages
blockExoticSubdeps: true
trustPolicy: no-downgrade
allowBuilds:
  - esbuild
  - sharp
  - "@parcel/watcher"
```
(Check exact key names/shapes for `allowBuilds` and exclusions in your pnpm 11.x docs — they changed from `onlyBuiltDependencies` in earlier versions.)

### npm `.npmrc` (npm 11) for projects not on pnpm
```ini
ignore-scripts=true
audit-level=high
fund=false
```
Then run needed scripts explicitly (e.g., `npm rebuild sharp`). With npm v12 defaults, use `npm approve-scripts` to build the allowlist in `package.json`.

### Dependabot with cooldown
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: "/"
    schedule: { interval: weekly }
    cooldown:
      default-days: 5
      semver-major-days: 14
      semver-patch-days: 3
    groups:
      react-next:
        patterns: ["react", "react-dom", "next", "@types/react*"]
      dev-tooling:
        dependency-type: development
  - package-ecosystem: github-actions
    directory: "/"
    schedule: { interval: weekly }
```

### Renovate equivalent
```json
{
  "extends": ["config:recommended"],
  "minimumReleaseAge": "3 days",
  "packageRules": [
    { "matchUpdateTypes": ["major"], "minimumReleaseAge": "14 days" },
    { "matchPackageNames": ["react", "react-dom", "next"], "groupName": "react-next" }
  ]
}
```

### Trusted publishing workflow (design-system package)
```yaml
# .github/workflows/release.yml
name: release
on: { push: { branches: [main] } }
permissions:
  contents: write
  id-token: write        # OIDC for npm trusted publishing
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinned-sha>
      - uses: pnpm/action-setup@<pinned-sha>
      - uses: actions/setup-node@<pinned-sha>
        with: { node-version: 24, registry-url: "https://registry.npmjs.org" }
      - run: pnpm install --frozen-lockfile
      - run: pnpm build && pnpm test
      - run: npm publish --access public   # no NPM_TOKEN; trusted publisher configured on npmjs.com
```

### Dependency review in PRs
```yaml
- uses: actions/dependency-review-action@<pinned-sha>
  with:
    fail-on-severity: high
    deny-licenses: GPL-3.0, AGPL-3.0
```

### New dependency checklist
| Check | Why |
|---|---|
| Needed at all? Platform API or existing dep? | Fewer deps = less risk |
| Install scripts present? | Code execution at install |
| Published < 7 days ago / maintainer change recently? | Takeover signal |
| Provenance attestation? | Build integrity |
| Weekly downloads, open issues, last commit | Maintenance health |
| Client bundle size impact | Performance + attack surface in browser |
| License compatible | Legal |

## Recommended Workflow
1. Commit lockfile; pin package manager via `packageManager` field.
2. Apply package-manager hardening (script allowlist, cooldown, exotic deps block).
3. Configure Renovate/Dependabot with cooldowns and groups.
4. Add PR dependency review + malware scanning; vulnerability alerts on default branch.
5. Harden CI: minimal permissions, SHA-pinned actions, secrets only in deploy jobs, no secrets for fork PRs.
6. Move publishing to trusted publishing; disallow tokens; enable 2FA (WebAuthn) for maintainers.
7. Incident runbook: identify affected versions from lockfiles, rotate CI/cloud secrets, purge caches (including remote build caches), pin known-good versions.

## Patterns
- **Cooldown + allowlist baseline** across all repos via shared config.
- **Install in a secretless job**, then pass artifacts to deploy jobs.
- **Private registry proxy** (Verdaccio, Artifactory, GitHub Packages) with quarantine policies for large orgs.
- **Reachability-based triage:** fix vulnerabilities in client/runtime paths first; dev-only tooling CVEs lower priority unless they run in CI with secrets.
- **Lockfile diff review** for unexpected new transitive packages.

## Anti-Patterns
- **`npm install` in CI** (lockfile drift) — Fix: `npm ci` / `--frozen-lockfile`.
- **Long-lived `NPM_TOKEN` in CI secrets** — worm target. Fix: trusted publishing.
- **Auto-merging all updates immediately** — ingests malicious releases. Fix: cooldown + tests + scope.
- **`dangerouslyAllowAllBuilds` / blanket script enabling** — Fix: explicit allowlist.
- **Ignoring `npm audit` entirely or failing builds on every low dev-dep advisory** — alert fatigue. Fix: severity + reachability policy.
- **Actions pinned by tag (`@v4`)** — tag can be moved. Fix: pin by SHA with Renovate/Dependabot updating.
- **Loading third-party scripts from mutable URLs without CSP** — Fix: CSP allowlist, SRI where versioned, self-host when possible.
- **Copy-pasting install commands from READMEs/AI output without checking package names** — typosquatting/slopsquatting. Fix: verify package on registry before installing.

## Accessibility
- Not directly applicable; but removing or swapping UI dependencies (e.g., replacing a compromised component library) must preserve accessibility behavior — include a11y regression tests in upgrade PRs.

## Responsive Design
- Not directly applicable.

## Performance
- Fewer and smaller dependencies reduce bundle size and install time; use `pnpm why`/`npm ls` to find duplicates; prefer platform APIs (fetch, Intl, structuredClone) over utility packages.

## Security
- OWASP Top 10:2025 A03 Software Supply Chain Failures (new, #3) and A08 Software or Data Integrity Failures.
- Build caches (Turborepo/Nx remote cache) are part of the supply chain — sign artifacts, restrict write access.
- Secrets exposure: malware targets `~/.npmrc`, cloud credentials, GitHub tokens, `.env` files — keep secrets out of repos, use OIDC to cloud providers, short-lived credentials.
- Next.js/Vite: a compromised dependency in client code can exfiltrate user data — CSP `connect-src` limits help contain.

## Testing
- CI gate: frozen install succeeds with no unapproved build scripts.
- Scheduled job: OSV-Scanner/audit against lockfile; open issues automatically.
- Periodic drill: simulate a compromised package advisory and time the response (identify, pin, rotate).

## Tooling
- pnpm 11 — Active (supply-chain defaults).
- npm CLI 11 / v12 (install-time security defaults announced July 2026) — Active; verify v12 availability in your Node distribution.
- npm trusted publishing — Active (GitHub Actions, GitLab.com, CircleCI cloud).
- Dependabot (cooldown, groups) — Active; Renovate (`minimumReleaseAge`) — Active.
- OSV-Scanner — Active; GitHub dependency-review-action — Active.
- Socket, Snyk, Aikido, Phylum-style malware detection — Commercial/Freemium.
- `@cyclonedx/cyclonedx-npm` — Active (SBOM).
- StepSecurity Harden-Runner — Active (CI egress monitoring).

## Framework Notes
- **React (Vite SPA):** everything bundled ships to users — scrutinize runtime deps more than dev deps; Vite/Rolldown native binaries rely on optional platform packages, not install scripts (fewer allowlist entries needed).
- **Next.js:** `sharp` (image optimization) and SWC/Turbopack native binaries may need build approvals depending on package manager; `output: 'standalone'` traces only used server deps — review its `node_modules` for unexpected packages; `@next/third-parties` and `next/script` for third-party scripts with CSP nonces.

## AI Agent Guidance
- Before adding a dependency, check whether an existing dependency or platform API covers the need; verify the exact package name and publisher on the registry.
- Do: add via the repo's package manager with the lockfile updated; respect cooldown/allowlist settings; note new install scripts in the PR.
- Don't: run `npm install` with `--ignore-scripts=false` overrides, add `dangerouslyAllowAllBuilds`, bypass `minimumReleaseAge`, use `npx some-unknown-package`, or add tokens to CI config.
- Verify: frozen install passes, no new unapproved build scripts, audit/dependency-review has no high/critical findings introduced.

## Examples
```bash
# Investigate a suspicious package in the tree
pnpm why suspicious-pkg
pnpm list --depth Infinity | grep suspicious-pkg
# Check publish time and provenance before upgrading
npm view some-pkg time --json | tail -n 5
npm view some-pkg@1.2.3 dist.attestations
```

## Related Skills
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — broader threat model
- [content-security-policy](../content-security-policy/Skill.md) — containing compromised client code
- [third-party-script-management](../third-party-script-management/Skill.md) — runtime third parties
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) — workspace settings, remote cache
- [frontend-ci-cd-pipelines](../frontend-ci-cd-pipelines/Skill.md) — CI hardening
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — secrets handling

## Sources
- [pnpm: Mitigating supply chain attacks](https://pnpm.io/supply-chain-security) — Official — pnpm 11 settings/defaults
- [GitHub Changelog: npm install-time security and GAT bypass2fa deprecation (2026-07-08)](https://github.blog/changelog/2026-07-08-npm-install-time-security-and-gat-bypass2fa-deprecation/) — Official — npm v12 defaults, token timeline
- [npm Docs: Trusted publishing](https://docs.npmjs.com/trusted-publishers/) — Official — OIDC requirements, provenance
- [GitHub Blog: Our plan for a more secure npm supply chain](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/) — Official — token/2FA roadmap
- [Dependabot options reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference) — Official — cooldown, groups
- [OWASP Top 10:2025](https://top10.owasp.org/2025) — Official — A03 Software Supply Chain Failures
- [Socket: pnpm 11 supply chain defaults](https://socket.dev/blog/pnpm-11-adds-new-supply-chain-protection-defaults) — Community (vendor) — context on Mini Shai-Hulud

## License / Usage Notes
Summarized from official docs and advisories; configuration examples original. Tools referenced have varied licenses (MIT/Apache-2.0/commercial).

## Quality Tier
S — built from official npm/GitHub/pnpm/OWASP sources dated 2025–2026; fast-moving area, re-verify key names (pnpm `allowBuilds` shape, npm v12 availability) quarterly.

## Status
Active

## Last Verified
2026-09-15
