# Frontend CI/CD Pipelines

## Summary
Designing CI/CD pipelines for React and Next.js apps on GitHub Actions: job graph (install -> static checks -> unit/component -> build -> E2E shards -> visual/perf), caching (package manager, `.next/cache`, Playwright browsers), artifacts (reports, traces), required checks, preview deployments, and safe secrets handling. Includes complete workflow YAML for Next.js with Vitest, Playwright sharding with merged reports, Storybook tests, Lighthouse CI and deployment gates.

## Category
Testing & QA

## Subcategories
GitHub Actions, caching, sharding, artifacts, required status checks, preview deployments, monorepo affected builds, secrets, supply chain hardening

## Problem It Solves
Frontend pipelines grow into 30-minute serial jobs with no caching, flaky E2E blocking merges, missing traces for debugging, and secrets exposed to untrusted PRs. A well-structured pipeline gives fast feedback (< 10 min for most PRs), reliable gates and secure deployments.

## When To Use
- Setting up CI for a new Next.js or Vite React repo.
- Speeding up or hardening an existing pipeline.
- Adding E2E, visual or performance checks to CI.

## When Not To Use
- Platform-specific deployment configuration details (Vercel/Netlify/containers): see [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md).
- Non-GitHub CI - principles transfer, YAML does not.

## Core Principles
1. Fail fast: cheapest checks first and in parallel.
2. Build once, test the artifact: reuse one production build across E2E shards and deploy what you tested.
3. Cache deterministically keyed on lockfiles and sources.
4. Always upload debugging artifacts on failure (`if: ${{ !cancelled() }}`).
5. Least privilege: minimal `permissions`, secrets only where needed, no secrets to untrusted code.
6. Required checks must be reliable; flaky or slow checks go non-blocking until fixed.

## Best Practices
- `concurrency` group per ref with `cancel-in-progress: true` for PRs.
- `actions/setup-node` with `cache: npm|pnpm|yarn` for package manager cache; `npm ci` / `pnpm install --frozen-lockfile`.
- Cache `.next/cache` per Next.js docs to avoid "No Cache Detected" and speed rebuilds.
- Install only needed Playwright browsers on PRs; cache `~/.cache/ms-playwright` keyed by Playwright version, or use the Playwright container image.
- Shard Playwright with `--shard` and `blob` reporter; merge into one HTML report.
- Set top-level `permissions: contents: read`; elevate per job only as needed.
- Pin third-party actions to a full commit SHA (at least for non-GitHub-owned actions).
- Use `pull_request` (not `pull_request_target`) for workflows that run PR code.
- Use `timeout-minutes` on every job.
- Use path filters or affected-graph tools (Turborepo/Nx) in monorepos.

## Implementation Guidance

### Pipeline shape
```
            +-> lint ---------+
install --> +-> typecheck ----+--> (all green) --> deploy preview/prod
            +-> unit (vitest) +
            +-> build --------+-> e2e shard 1..N -> merge-reports
                              +-> lighthouse (key URLs)
            +-> storybook tests / visual (parallel)
```

### .github/workflows/ci.yml (Next.js)
```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

env:
  NEXT_TELEMETRY_DISABLED: 1

jobs:
  checks:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    strategy:
      matrix:
        task: [lint, typecheck, 'test:ci']
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npm run ${{ matrix.task }}
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() && matrix.task == 'test:ci' }}
        with: { name: coverage, path: coverage/, retention-days: 7 }

  build:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - uses: actions/cache@v4
        with:
          path: ${{ github.workspace }}/.next/cache
          key: ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-${{ hashFiles('**/*.js', '**/*.jsx', '**/*.ts', '**/*.tsx') }}
          restore-keys: |
            ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-
      - run: npm run build
        env:
          NEXT_PUBLIC_API_URL: http://localhost:4010
      - uses: actions/upload-artifact@v4
        with:
          name: next-build
          path: |
            .next/
            !.next/cache
          include-hidden-files: true
          retention-days: 1

  e2e:
    needs: build
    runs-on: ubuntu-latest
    timeout-minutes: 30
    strategy:
      fail-fast: false
      matrix:
        shardIndex: [1, 2, 3, 4]
        shardTotal: [4]
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - uses: actions/download-artifact@v4
        with: { name: next-build, path: .next }
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test --project=chromium --shard=${{ matrix.shardIndex }}/${{ matrix.shardTotal }}
        env:
          PLAYWRIGHT_WEB_SERVER_COMMAND: npm run start
          E2E_USER_EMAIL: ${{ secrets.E2E_USER_EMAIL }}
          E2E_USER_PASSWORD: ${{ secrets.E2E_USER_PASSWORD }}
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: blob-report-${{ matrix.shardIndex }}
          path: blob-report
          retention-days: 7

  e2e-report:
    needs: e2e
    if: ${{ !cancelled() }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - uses: actions/download-artifact@v4
        with: { path: all-blob-reports, pattern: blob-report-*, merge-multiple: true }
      - run: npx playwright merge-reports --reporter html ./all-blob-reports
      - uses: actions/upload-artifact@v4
        with: { name: playwright-report, path: playwright-report, retention-days: 14 }
```
Notes:
- In `playwright.config.ts`, read `process.env.PLAYWRIGHT_WEB_SERVER_COMMAND ?? 'npm run build && npm run start'` so CI reuses the downloaded build.
- `NEXT_PUBLIC_*` values are inlined at build time; build with the values E2E expects. Server-only env vars can be set at `next start`.
- `fullyParallel: true` balances shards at test level.
- Confirm current action majors (checkout/setup-node v6, upload/download-artifact v4 per Playwright docs at time of writing) - Check current docs.

### Storybook and visual job
```yaml
  storybook:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v6
        with: { fetch-depth: 0 }   # needed for TurboSnap/changed detection
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx vitest run --project=storybook
```

### Caching Playwright browsers (optional)
```yaml
      - id: pw
        run: echo "version=$(node -p "require('@playwright/test/package.json').version")" >> "$GITHUB_OUTPUT"
      - uses: actions/cache@v4
        id: pw-cache
        with: { path: ~/.cache/ms-playwright, key: pw-${{ runner.os }}-${{ steps.pw.outputs.version }} }
      - if: steps.pw-cache.outputs.cache-hit != 'true'
        run: npx playwright install --with-deps chromium
      - if: steps.pw-cache.outputs.cache-hit == 'true'
        run: npx playwright install-deps chromium
```

### Preview deployments and post-deploy tests
- Vercel/Netlify create preview URLs per PR; trigger a workflow on `deployment_status` (state `success`) and run `@smoke` Playwright + Lighthouse with `PLAYWRIGHT_BASE_URL=${{ github.event.deployment_status.target_url }}` (verify event payload field names in GitHub docs).
- For protected previews, pass a bypass token from secrets as a header via `extraHTTPHeaders` (Check current Vercel docs).

### Required checks policy
| Check | Required on PR | Notes |
|---|---|---|
| lint, typecheck, unit | Yes | Fast, deterministic |
| build | Yes | |
| e2e smoke (chromium) | Yes | Merged report |
| storybook tests + a11y | Yes | |
| visual review (Chromatic/Argos) | Yes, via approval status | Human approval |
| Lighthouse | Warn first, then required for key URLs | Variance |
| cross-browser full, quarantine | No (nightly) | |

## Recommended Workflow
1. Start with lint/typecheck/unit/build in parallel; make them required.
2. Add Playwright E2E using the build artifact; add sharding when > 5-8 minutes.
3. Add caches (package manager, `.next/cache`, browsers) and measure gains.
4. Add Storybook/visual and Lighthouse jobs.
5. Harden: permissions, SHA-pinned third-party actions, secrets scoping, `timeout-minutes`.
6. Add nightly workflow for full browser matrix and quarantine verification.
7. Review pipeline duration and flake metrics monthly.

## Patterns
- **Build once**: artifact upload/download between build and E2E/perf jobs.
- **Matrix of tasks**: single job definition for lint/typecheck/test.
- **Affected-only in monorepos**: `turbo run test --filter=...[origin/main]` or `nx affected -t test`.
- **Merge queue**: GitHub merge queue runs required checks on the merged result (`merge_group` event trigger).
- **Nightly deep run**: schedule + `workflow_dispatch`.

## Anti-Patterns
- **Building in every E2E shard**: multiplies time; results can differ. Fix: build artifact.
- **`pull_request_target` checking out PR head with secrets**: code execution with secrets from forks. Fix: `pull_request`; split privileged steps into `workflow_run` with no untrusted code execution.
- **No artifacts on failure**: undebuggable flakes. Fix: `if: ${{ !cancelled() }}` uploads.
- **Caching `node_modules` keyed loosely**: stale/broken installs. Fix: cache package manager store via setup-node; `npm ci`.
- **Unpinned third-party actions (`@main`)**: supply-chain risk. Fix: pin SHA, use Dependabot for updates.
- **Excessive `permissions: write-all`**. Fix: least privilege per job.
- **Visual/LHCI as hard gates from day one**: noise erodes trust. Fix: warn -> required after stabilization.

## Accessibility
Include accessibility checks as required jobs (Storybook a11y `error`, Playwright axe on key pages); ownership and rules in [automated-accessibility-testing](../automated-accessibility-testing/Skill.md).

## Responsive Design
Mobile-viewport E2E projects in PR smoke if mobile traffic is significant; full device matrix nightly ([cross-browser-and-device-testing](../cross-browser-and-device-testing/Skill.md)).

## Performance
- Targets: checks < 5 min, full PR pipeline < 15 min.
- Use larger runners for E2E if cheaper than wall-clock time; keep workers aligned with vCPUs.
- Turbopack/`next build` caching via `.next/cache`; Turborepo remote cache for monorepos.
- Cancel superseded runs via `concurrency`.

## Security
- Top-level `permissions: contents: read`; add `pull-requests: write` only to jobs that comment.
- Secrets are not passed to workflows triggered from forks on `pull_request`; design E2E to run without secrets for forks (mock auth) or skip gracefully.
- Never echo secrets; avoid `set -x` in steps with secrets.
- Use OIDC for cloud deploys instead of long-lived keys where supported.
- Scan dependencies and lockfile changes ([dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md)).
- Artifacts (traces, videos, coverage) are downloadable by anyone with repo read access; set short retention.

## Testing
Test the pipeline itself: open a PR that intentionally fails each gate; verify the right job fails, artifacts upload, and cancellation works.

## Tooling
| Tool | Notes (2026-09-15) |
|---|---|
| `actions/checkout@v6`, `actions/setup-node@v6` | Majors shown in Playwright CI docs |
| `actions/cache@v4`, `actions/upload-artifact@v4`, `actions/download-artifact@v4` | Check current majors |
| Playwright blob reporter + `merge-reports` | Sharded reporting |
| Turborepo / Nx | Affected tasks, remote cache |
| Dependabot / Renovate | Action and dependency updates |
| `actionlint` | Workflow linting |

## Framework Notes
- **Next.js**: Persist `.next/cache`; `NEXT_PUBLIC_*` requires rebuild per environment; `next build` output (`.next/`) plus `public/`, `package.json` and `node_modules` are needed for `next start`. For `output: 'standalone'`, test the standalone server (`node .next/standalone/server.js`, copy `public` and `.next/static`) to match production.
- **React (Vite SPA)**: Build artifact is `dist/`; E2E against `vite preview` or a static server; `import.meta.env.VITE_*` inlined at build.

## AI Agent Guidance
- Do: validate YAML with `actionlint` if available; keep job names stable (required checks reference them).
- Do: add artifacts upload for any new test job.
- Do: use secrets via `${{ secrets.NAME }}` and never write secret values into files or logs.
- Don't: switch to `pull_request_target`, broaden `permissions`, or disable required checks without explicit user approval.
- Don't: rename required jobs without flagging branch protection updates.
- Before done: workflow syntax valid, a test run passes (or clearly documented as needing a push to verify), caches keyed on lockfile.

## Examples
Minimal Vite SPA workflow:
```yaml
name: ci
on: [pull_request]
permissions: { contents: read }
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22, cache: pnpm }
      - run: corepack enable && pnpm install --frozen-lockfile
      - run: pnpm lint && pnpm typecheck && pnpm vitest run
      - run: pnpm build
      - run: pnpm exec playwright install --with-deps chromium
      - run: pnpm exec playwright test
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with: { name: playwright-report, path: playwright-report/, retention-days: 7 }
```
Note: when using `cache: pnpm`, pnpm must be available before `setup-node` runs (e.g., `pnpm/action-setup`) - Check current setup-node docs.

## Related Skills
- [frontend-testing-strategy](../frontend-testing-strategy/Skill.md) - what runs where
- [playwright-e2e-testing](../playwright-e2e-testing/Skill.md) - sharding and reports
- [lighthouse-ci](../lighthouse-ci/Skill.md) - performance job
- [visual-regression-testing](../visual-regression-testing/Skill.md) - visual job
- [flaky-test-management](../flaky-test-management/Skill.md) - quarantine jobs
- [monorepo-frontend-architecture](../monorepo-frontend-architecture/Skill.md) - affected builds
- [dependency-supply-chain-security](../dependency-supply-chain-security/Skill.md) - action pinning and scanning
- [nextjs-deployment-and-self-hosting](../nextjs-deployment-and-self-hosting/Skill.md) - deploy targets
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) - env var handling

## Sources
- [Next.js CI build caching](https://nextjs.org/docs/app/guides/ci-build-caching) - Official - `.next/cache` GitHub Actions snippet
- [Playwright CI (GitHub Actions)](https://playwright.dev/docs/ci-intro) - Official - workflow, action versions, artifacts
- [Playwright Sharding](https://playwright.dev/docs/test-sharding) - Official - blob reports and merge-reports
- [GitHub Actions documentation](https://docs.github.com/actions) - Official - permissions, concurrency, events, security hardening

## License / Usage Notes
Workflow YAML is original, adapted from patterns in official docs. GitHub Actions usage subject to GitHub terms.

## Quality Tier
A - Built on official Next.js, Playwright and GitHub docs; some action majors and preview-deployment event details flagged "Check current docs".

## Status
Active

## Last Verified
2026-09-15
