# Performance Profiling with DevTools

## Summary
Performance profiling turns "it feels slow" into evidence: a trace showing which task, script, component, request or rendering step is responsible. The main tools are:
- The Chrome DevTools Performance panel: live Core Web Vitals with CrUX field data, calibrated CPU and network throttling, an Insights sidebar shared with Lighthouse 13, annotations, third-party dimming, custom tracks.
- React DevTools Profiler, plus React performance tracks in the Chrome trace.
- Lighthouse, for lab audits.
- Chrome DevTools MCP, which lets AI agents record and analyze traces programmatically.

## Category
Performance

## Subcategories
Performance panel, Insights, live metrics, CPU/network throttling, flame charts, React Profiler, React performance tracks, User Timing, extensibility API, Lighthouse, Chrome DevTools MCP, production profiling

## Problem It Solves
Guess-driven optimization that wastes effort or makes things worse. Profiling gives root causes for LCP, INP, CLS, jank, and slow React renders, and makes before/after comparisons reproducible.

## When To Use
- Diagnosing any CWV problem after field data identifies the metric and page.
- Investigating slow interactions, janky scrolling, long loads, or slow React updates.
- Validating a performance fix before shipping.
- Agent-driven verification loops ([frontend-agent-verification-loop](../frontend-agent-verification-loop/Skill.md)).

## When Not To Use
- Deciding whether a problem exists at scale. Use field data first ([performance-budgets-and-rum](../performance-budgets-and-rum/Skill.md)).
- Memory growth over time. Use the Memory panel workflow in [javascript-memory-leaks](../javascript-memory-leaks/Skill.md).

## Core Principles
1. **Profile production builds.** Dev builds (React dev mode, HMR, Next dev compilation) distort timings by several times.
2. **Throttle to match users.** Use calibrated CPU throttling (DevTools can calibrate presets for low- and mid-tier devices) and a realistic network profile. Your laptop is not your p75 user.
3. **One scenario, recorded repeatably.** Same steps, clean profile (incognito, no extensions), multiple runs.
4. **Start from Insights, confirm in the flame chart.** Insights point; the Main track proves.
5. **Compare before/after traces**, not memories.

## Best Practices
- Use a clean Chrome profile or Guest window. Extensions inject scripts into traces.
- Enable the "Field data" (CrUX) comparison in live metrics to check that your local setup reproduces real-user conditions.
- Use "Dim 3rd parties" and ignore-listing to focus on first-party code. Still check third-party impact separately.
- Annotate traces (label entries, link cause to effect) and save or export them for PRs and issues.
- Add `performance.mark`/`measure` around app-specific phases (route transition, data load, render). They appear in the Timings track. Use the DevTools extensibility API to create custom tracks.
- For React: use the Profiler tab (commit durations, "why did this render") and React 19.2+ performance tracks (Scheduler and Components tracks) in the Chrome trace.
- For INP: record, perform the interaction, stop. Inspect the Interactions track and the INP breakdown insight.
- For load: use "Record and reload." Read the LCP breakdown, request discovery, render-blocking, third parties, and network dependency tree insights.

## Implementation Guidance

### Setup checklist
| Setting | Recommendation |
|---|---|
| Build | `next build && next start` / `vite build && vite preview` |
| React profiling in prod | Next: `next build --profile`. Vite: alias `react-dom/client` to the profiling build if you need Profiler data in prod |
| Browser | Chrome stable, Guest profile, DevTools undocked |
| CPU | Calibrated "mid-tier mobile" preset, or 4× for laptops |
| Network | "Slow 4G" or custom matching CrUX RTT for load traces. Usually none for interaction traces |
| Cache | Disable for first-visit scenarios; enable for repeat-visit scenarios |
| Screenshots | On for load (filmstrip); off for long interaction sessions to reduce overhead |

### Which view answers which question
| Question | Where to look |
|---|---|
| What is the LCP element and why is it late? | Live metrics → LCP element; trace Insights → LCP breakdown, LCP request discovery |
| Which interaction is slow and which phase? | Interactions track + INP breakdown insight; Main track under the interaction |
| What caused a layout shift? | Layout shifts track + "Layout shift culprits" insight |
| Which script is blocking? | Main track flame chart (bottom-up / call tree grouped by URL or third party) |
| Why did React re-render? | React DevTools Profiler (enable "Record why each component rendered") |
| Is style/layout the problem? | Main track purple blocks, "Forced reflow" insight, CSS selector stats |
| Which requests block rendering? | Render-blocking insight, Network track, Network panel Priority/Initiator |
| Lab score for CI? | Lighthouse (DevTools panel or CLI) / LHCI |

### User Timing with a custom DevTools track
```ts
export function measureRouteRender(route: string, start: number) {
  performance.measure(`render ${route}`, {
    start,
    end: performance.now(),
    detail: {
      devtools: { dataType: 'track-entry', track: 'App: routes', color: 'tertiary', tooltipText: route },
    },
  });
}
```

### React Profiler component (programmatic)
```tsx
import { Profiler, type ProfilerOnRenderCallback } from 'react';

const onRender: ProfilerOnRenderCallback = (id, phase, actualDuration, baseDuration) => {
  if (actualDuration > 16) console.warn(`[profiler] ${id} ${phase} ${actualDuration.toFixed(1)}ms (base ${baseDuration.toFixed(1)}ms)`);
};

export function ProfiledResults({ children }: { children: React.ReactNode }) {
  return <Profiler id="SearchResults" onRender={onRender}>{children}</Profiler>;
}
```
`<Profiler>` is disabled in production builds unless you use a profiling build.

### Chrome DevTools MCP (agents)
```json
{ "mcpServers": { "chrome-devtools": { "command": "npx", "args": ["-y", "chrome-devtools-mcp@latest"] } } }
```
Performance tools:
- `performance_start_trace` (`pageId`, `reload`, `autoStop`, `filePath`)
- `performance_stop_trace` (`pageId`, `filePath`)
- `performance_analyze_insight` (`pageId`, `insightSetId`, `insightName`)

Emulation: `emulate` (`cpuThrottlingRate`, `networkConditions`, `viewport`, `userAgent`, ...) and `resize_page`.

Typical agent loop:
1. Navigate.
2. `emulate` with cpuThrottlingRate 4 and a Slow 4G network.
3. `performance_start_trace` with `reload: true`, `autoStop: true`.
4. Read the summary.
5. `performance_analyze_insight` for `LCPBreakdown`/`INPBreakdown`/`CLSCulprits` (use the insight names the trace summary reports).
6. Fix, then re-trace.

### Lighthouse CLI (lab)
```bash
npx lighthouse https://localhost:3000/ --preset=perf --form-factor=mobile --output=json --output-path=./lh.json
```
Lighthouse 13 uses insight-based audits aligned with DevTools. Scoring is unchanged and based on metrics (FCP, SI, LCP, TBT, CLS).

## Recommended Workflow
1. Start from field data: metric, page template, device class, and attribution (element, interaction target).
2. Build for production locally, or profile a staging deployment.
3. Configure throttling to match field conditions (compare live metrics with CrUX field data).
4. Record the scenario 3 times. Pick the median trace.
5. Read the Insights sidebar. Drill into Main/Network/Interactions tracks. Annotate the root cause.
6. Form a single hypothesis. Change one thing.
7. Re-record the same scenario. Compare metrics and the specific task durations. Save both traces.
8. Ship and verify in RUM.

## Patterns
- **Median-of-N traces** for noisy measurements.
- **Annotated trace in PR**: attach before/after traces with labels.
- **User Timing instrumentation** of app phases for consistent landmarks across traces and RUM.
- **Agent trace loop** via Chrome DevTools MCP with fixed emulation settings.
- **Bottom-up by third party**: group the bottom-up view by domain to quantify vendor cost.

## Anti-Patterns
- **Profiling `next dev` / `vite` dev server.** Dev overhead dominates. Fix: production build.
- **Unthrottled profiling on a fast laptop.** Nothing looks slow. Fix: calibrated CPU throttling.
- **Chasing a single Lighthouse score change of ±5.** Noise. Fix: median of runs; focus on metrics and subparts.
- **Optimizing from the call tree without context** (e.g., a "self time" hotspot that runs after the metric). Fix: correlate with the metric's time range.
- **Extensions enabled.** Injected scripts pollute traces. Fix: Guest/clean profile.
- **Leaving Profiler instrumentation and verbose marks in production** without sampling. Fix: guard by environment or sample.

## Accessibility
- Profile with assistive tech enabled when possible. Screen readers and accessibility tree computation add work, and very large DOMs can make AT sluggish.
- Include keyboard interactions in INP profiling scenarios.

## Responsive Design
- Profile at mobile viewport and DPR (Device Mode) for mobile issues. Layout and image decode costs change with viewport.
- Remote-debug real Android devices (`chrome://inspect`) for ground truth.

## Performance
- Tracing adds overhead, especially with screenshots, memory, or advanced paint instrumentation. Compare traces recorded with identical settings.

## Security
- Traces and HAR files can contain URLs with tokens, cookies (HAR), and PII in screenshots. Sanitize before sharing. DevTools can export HARs without sensitive data by default; verify.
- Chrome DevTools MCP gives agents full browser control. Use a separate profile without personal sessions.

## Testing
- Automate lab regression with Lighthouse CI ([lighthouse-ci](../lighthouse-ci/Skill.md)) and Playwright tracing (`page.context().tracing` / CDP `Tracing.start`) for key flows.
- Store traces as CI artifacts for failed performance checks.

## Tooling
- Chrome DevTools Performance panel (live metrics + CrUX, Insights, annotations, calibrated throttling, custom tracks): Active.
- Lighthouse 13: Active.
- React DevTools Profiler and React performance tracks (React 19.2+): Active.
- Chrome DevTools MCP (`chrome-devtools-mcp`): Active.
- WebPageTest, DebugBear, Calibre (synthetic with traces): Active.
- Firefox Profiler and Safari Web Inspector Timelines, for cross-browser checks (Safari INP now measurable): Active.

## Framework Notes
- **React (Vite SPA)**: profile `vite preview` builds. For component-level analysis use React DevTools Profiler with a profiling build. React-specific fixes are in [react-performance-optimization](../react-performance-optimization/Skill.md).
- **Next.js**:
  - Profile `next start` builds. `next build --profile` enables React profiling in production.
  - Server-side timing (TTFB) needs server tracing: OpenTelemetry via `instrumentation.ts`, or `Server-Timing` headers, which appear in DevTools Network Timing ([frontend-observability](../frontend-observability/Skill.md)).
  - Streaming shows as a long HTML response in the Network track; look at when chunks arrive relative to FCP/LCP.
  - More in [nextjs-performance](../nextjs-performance/Skill.md).

## AI Agent Guidance
- Do: profile production builds with fixed throttling; cite specific insights, tasks, and durations in findings.
- Do: use Chrome DevTools MCP when available: emulate, trace, analyze insights, fix, re-trace.
- Don't: claim improvements from dev-server timings or single runs.
- Don't: share raw traces or HARs externally without sanitizing.
- Before declaring done: before/after traces under identical settings show the targeted metric or task improved, with no new long tasks, layout shifts, or regressions in other insights.

## Examples
```ts
// Server-Timing header from a Next.js Route Handler (visible in DevTools Network → Timing)
export async function GET() {
  const t0 = performance.now();
  const data = await loadData();
  const dbMs = performance.now() - t0;
  return Response.json(data, { headers: { 'Server-Timing': `db;dur=${dbMs.toFixed(1)}` } });
}
```

## Related Skills
- [core-web-vitals](../core-web-vitals/Skill.md): which metric to profile
- [inp-optimization](../inp-optimization/Skill.md): interaction traces
- [lcp-optimization](../lcp-optimization/Skill.md): load traces
- [javascript-memory-leaks](../javascript-memory-leaks/Skill.md): memory profiling
- [lighthouse-ci](../lighthouse-ci/Skill.md): automated lab checks
- [mcp-for-frontend-development](../mcp-for-frontend-development/Skill.md): DevTools MCP setup
- [ai-frontend-debugging-workflow](../ai-frontend-debugging-workflow/Skill.md): agent debugging loop

## Sources
- [Chrome DevTools: Performance features reference](https://developer.chrome.com/docs/devtools/performance/reference) (Official): live metrics, CrUX field data, throttling calibration, insights, annotations, 3rd-party dimming
- [Lighthouse 13 release](https://developer.chrome.com/blog/lighthouse-13-0) (Official): insight-based audits, unchanged scoring
- [ChromeDevTools/chrome-devtools-mcp tool reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md) (Open Source): performance and emulation tool names and parameters
- [Chrome DevTools: Performance extensibility API](https://developer.chrome.com/docs/devtools/performance/extension) (Official): custom tracks via User Timing `detail.devtools`
- [React: Profiler](https://react.dev/reference/react/Profiler) (Official): onRender API
- [React 19.2: Performance Tracks](https://react.dev/blog/2025/10/01/react-19-2) (Official): Scheduler/Components tracks
- [DebugBear: Performance insights in Lighthouse and DevTools](https://www.debugbear.com/blog/performance-insights-devtools-lighthouse) (Community): insight migration context

## License / Usage Notes
Summarized. chrome-devtools-mcp Apache-2.0. Examples original.

## Quality Tier
S: Verified against current DevTools, Lighthouse 13 and DevTools MCP docs, with a concrete, reproducible procedure.

## Status
Active

## Last Verified
2026-09-15
