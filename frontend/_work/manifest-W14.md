# Manifest: W14 Data Visualization

Scope: React + Next.js (TypeScript) per TAXONOMY scope note (2026-09-15). All 13 assigned slugs written; no slugs added, none skipped (sparklines are covered in kpi-and-stat-components; network/gantt charts are noted as gaps).

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| data-visualization-principles | Data Visualization Principles | Data Visualization | Agnostic (React/Next.js notes) | A | Active | https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary |
| chart-type-selection | Chart Type Selection | Data Visualization | Agnostic (React/Next.js notes) | A | Active | https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary |
| d3-fundamentals | D3 Fundamentals (D3 in React) | Data Visualization | React, Next.js | A | Active | https://d3js.org/getting-started |
| recharts | Recharts | Data Visualization | React, Next.js | A | Active | https://github.com/recharts/recharts/wiki/3.0-migration-guide |
| chartjs | Chart.js (with react-chartjs-2) | Data Visualization | React, Next.js | A | Active | https://www.chartjs.org/docs/latest/general/performance.html |
| echarts | Apache ECharts (in React and Next.js) | Data Visualization | React, Next.js | A | Active | https://echarts.apache.org/handbook/en/basics/release-note/v6-upgrade-guide/ |
| nivo-and-visx | nivo and visx | Data Visualization | React, Next.js | B | Active | https://github.com/airbnb/visx/releases |
| dashboard-design | Dashboard Design | Data Visualization | React, Next.js | A | Active | https://www.nngroup.com/articles/dashboards-preattentive/ |
| accessible-data-visualization | Accessible Data Visualization | Data Visualization | React, Next.js | A | Active | https://chartability.fizz.studio/ |
| realtime-data-ui | Realtime Data UI | Data Visualization | React, Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events |
| maps-and-geospatial-ui | Maps and Geospatial UI | Data Visualization | React, Next.js | B | Active | https://maplibre.org/news/ |
| large-dataset-visualization-performance | Large Dataset Visualization Performance | Data Visualization | React, Next.js | A | Active | https://github.com/leeoniya/uPlot |
| kpi-and-stat-components | KPI and Stat Components | Data Visualization | React, Next.js | A | Active | https://www.nngroup.com/articles/dashboards-preattentive/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| D3 Getting Started | https://d3js.org/getting-started | Official | ESM install; React guidance (D3 math, React DOM; axes via refs) | Canonical React integration model | High | 2026-09-15 |
| d3 releases / npm | https://github.com/d3/d3/releases | Official | v7.9.0 latest (Mar 2024), no v8 | Version accuracy | High | 2026-09-15 |
| Observable Plot releases | https://github.com/observablehq/plot/releases | Official | 0.6.17; Arrow support, difference mark | Alternative for quick charts | High | 2026-09-15 |
| Recharts 3.0 migration guide | https://github.com/recharts/recharts/wiki/3.0-migration-guide | Official | Breaking changes, accessibilityLayer default, YAxis width auto, TooltipContentProps | v2→v3 migration correctness | High | 2026-09-15 |
| Recharts status update 2026 (#7355) | https://github.com/recharts/recharts/issues/7355 | Official | 3.9 roadmap, docs moved to recharts.github.io | Current project status | High | 2026-09-15 |
| Recharts v2 deprecation (#7361) | https://github.com/recharts/recharts/issues/7361 | Official | <3.0 deprecated on npm (May 2026) | Upgrade urgency | High | 2026-09-15 |
| Recharts performance guide | https://recharts.github.io/en-US/guide/performance/ | Official | Memoization, component isolation, eslint-plugin-react-perf rules, throttling | Performance guidance | High | 2026-09-15 |
| Chart.js performance | https://www.chartjs.org/docs/latest/general/performance.html | Official | parsing:false, normalized, decimation, workers, tick settings | Large data config | High | 2026-09-15 |
| Chart.js accessibility | https://www.chartjs.org/docs/latest/general/accessibility.html | Official | role=img, aria-label, fallback content | Canvas a11y baseline | High | 2026-09-15 |
| Chart.js releases | https://github.com/chartjs/Chart.js/releases | Official | 4.5.1 latest; no v5 | Version accuracy | High | 2026-09-15 |
| ECharts 6 features | https://echarts.apache.org/handbook/en/basics/release-note/v6-feature/ | Official | New theme/dark mode, matrix coord, chord, axis break, jitter, custom series, MCP | Current capabilities | High | 2026-09-15 |
| ECharts v5→v6 migration | https://echarts.apache.org/handbook/en/basics/release-note/v6-upgrade-guide/ | Official | v5 theme import, outerBoundsMode, nameMoveOverlap, richInheritPlainLabel | Upgrade correctness | High | 2026-09-15 |
| ECharts releases | https://github.com/apache/echarts/releases | Official | 6.1.0 (May 2026) | Version accuracy | High | 2026-09-15 |
| ECharts Canvas vs SVG | https://echarts.apache.org/handbook/en/best-practices/canvas-vs-svg/ | Official | Renderer selection, SVG VDOM gains since 5.3 | Renderer thresholds | High | 2026-09-15 |
| ECharts SSR | https://echarts.apache.org/handbook/en/how-to/cross-platform/server/ | Official | ssr:true + renderToSVGString, lightweight client runtime | Next.js server-rendered charts | High | 2026-09-15 |
| nivo releases / repo | https://github.com/plouc/nivo | Official | 0.98.0 React 19; SVG/canvas/HTML variants; @nivo/static | Compatibility and SSR | Medium-High | 2026-09-15 |
| visx releases / MIGRATION | https://github.com/airbnb/visx/releases | Official | v4.0.0 (June 2026) React 18/19 peers | Compatibility | High | 2026-09-15 |
| Vega-Lite releases | https://github.com/vega/vega-lite/releases | Official | v6.4.3 (Apr 2026) | Prototyping tool version | High | 2026-09-15 |
| uPlot | https://github.com/leeoniya/uPlot | Open Source | Size (~50KB), benchmarks, limitations | Large/streaming time series | High | 2026-09-15 |
| Apache Arrow JS | https://arrow.apache.org/docs/js/ | Official | tableFromIPC, typed columnar vectors, v21.x | Binary transport for big data | High | 2026-09-15 |
| deck.gl what's new / releases | https://deck.gl/docs/whats-new | Official | 9.4 WebGPU parity, @deck.gl/maplibre, widgets, globe | GPU rendering for maps/big data | High | 2026-09-15 |
| MapLibre news | https://maplibre.org/news/ | Official | v5 (globe) and v6 (mid-2026) timeline | Open map engine status | Medium (dates from summary) | 2026-09-15 |
| MapLibre GL JS releases | https://github.com/maplibre/maplibre-gl-js/releases | Official | v6.x features, RTL plugin deprecation, accessible draggable markers | Engine features | Medium | 2026-09-15 |
| Mapbox GL JS LICENSE | https://github.com/mapbox/mapbox-gl-js/blob/main/LICENSE.txt | Official | Proprietary since v2; BSD-3 ≤ v1.13 | Licensing risk | High | 2026-09-15 |
| Leaflet releases | https://github.com/Leaflet/Leaflet/releases | Official | 1.9.4 stable; 2.0 alpha breaking changes | Engine choice | High | 2026-09-15 |
| Chartability | https://chartability.fizz.studio/ | Community (research) | POUR+CAF, quick 14 / full 50 heuristics | Chart a11y audit method | High | 2026-09-15 |
| W3C WAI Complex Images | https://www.w3.org/WAI/tutorials/images/complex/ | Official | Short + long description approaches | Text alternative standard | High | 2026-09-15 |
| Highcharts Accessibility module | https://www.highcharts.com/docs/accessibility/accessibility-module | Official (vendor) | Keyboard nav, descriptions, data table, sonification | Reference implementation | High | 2026-09-15 |
| FT Visual Vocabulary | https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary | Community/Open Source | Nine relationship categories and chart forms | Chart selection taxonomy | High | 2026-09-15 |
| Datawrapper: colorblindness pt 2 | https://www.datawrapper.de/blog/colorblindness-part2 | Community | Safe hues, lightness, non-color cues | CVD color rules | High | 2026-09-15 |
| NN/g dashboards & preattentive | https://www.nngroup.com/articles/dashboards-preattentive/ | Community (research) | Operational vs analytical, avoid pies/gauges/3D | Dashboard design | High | 2026-09-15 |
| MDN Server-sent events | https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events | Official | Event format, retry, Last-Event-ID, 6-connection HTTP/1.1 limit | Realtime transport | High | 2026-09-15 |
| Chrome WebSocketStream | https://developer.chrome.com/docs/capabilities/web-apis/websocketstream | Official | Backpressure rationale; Chrome-only | Realtime backpressure | High | 2026-09-15 |
| Claude Code bundled `dataviz` skill | (local bundled agent skill) | Community (agent skill) | Color jobs, series-count ladder, anti-pattern catalog, stat tile guidance | Community agent-skill conventions for charts | Medium-High | 2026-09-15 |
| Tufte / Few / Knaflic books | n/a (books) | Community (books) | Data-ink, small multiples, bullet graphs, sparklines, emphasis | Foundational principles | High | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Sparklines | Tufte / Few | Bundled dataviz stat tile guidance | kpi-and-stat-components |
| Chart color rules (CVD, sequential/diverging) | Datawrapper colorblind guide | Bundled dataviz color-formula; Carbon palette guidance (unfetched) | data-visualization-principles (cross-ref accessible-data-visualization) |
| Canvas vs SVG vs WebGL thresholds | ECharts renderer guide + uPlot benchmarks | Chart.js performance doc; deck.gl docs | large-dataset-visualization-performance |
| Chart SSR in Next.js | ECharts SSR docs | Recharts/nivo/Chart.js client-only notes | Per-library Framework Notes (echarts canonical example) |
| Gauges vs bullets | NN/g + Few | FT Visual Vocabulary | chart-type-selection, kpi-and-stat-components |
| Operational live dashboards | MDN SSE + WebSocketStream | dashboard-design operational type | realtime-data-ui |

## Gaps

- WebSearch budget was exhausted early (shared session limit), so several items were fetched directly or not verified: react-map-gl and react-leaflet current majors/React 19 status, echarts-for-react React 19 maintenance, react-chartjs-2 current version, Recharts newest 3.x hooks and `responsive` prop.
- IBM Carbon Data Visualization pages and Material 3 data-viz guidance failed to load (truncated content). Carbon palette and accessibility rules are not incorporated directly.
- MapLibre v6 breaking changes and exact release dates were not confirmed from the changelog (the news summary had inconsistent dates).
- ECharts `large`/`largeThreshold`/`progressive` defaults were not verified (option page not retrievable).
- Community SKILL.md / .cursor/rules for charts were not retrievable (cursor.directory 429; anthropics/skills lists no viz skill). Only the local bundled `dataviz` skill was used.
- Mapbox pricing specifics (map-load billing tiers) were not verified; only the license was.
- Not covered as standalone skills (candidates for future slugs): network/graph visualization (Sigma.js, Cytoscape, react-flow for diagrams), Gantt/timeline charts, Highcharts/AG Charts commercial libraries, Vega-Lite/Observable Plot in React, sonification.
- Mark-count thresholds (SVG/Canvas/WebGL) are practitioner syntheses, not benchmarked on 2026 devices.
