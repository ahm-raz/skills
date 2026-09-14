# Maps and Geospatial UI

## Summary
How to build interactive maps and geospatial data views in React and Next.js: choosing a map engine (MapLibre GL JS, Leaflet, Mapbox GL JS, deck.gl overlays, d3-geo for static maps), tile and basemap sourcing (vector tiles, PMTiles, provider licensing), data layers (markers, clustering, choropleths, heatmaps), performance for large point sets, SSR constraints, and map accessibility.

## Category
Data Visualization

## Subcategories
MapLibre GL JS, react-map-gl, Leaflet, react-leaflet, Mapbox licensing, deck.gl, vector tiles, PMTiles, choropleth, clustering, geocoding UI

## Problem It Solves
Map features are deceptively complex: licensing and billing surprises (Mapbox GL v2+ is proprietary), `window is not defined` SSR crashes, thousands of DOM markers freezing the page, misleading choropleths of raw counts, unattributed OpenStreetMap tiles violating usage policy, and maps that are impossible to use with a keyboard or screen reader.

## When To Use
- Store locators, fleet/asset tracking, delivery zones, and real-estate search.
- Geographic analytics: choropleths, density, flows.
- Any feature requiring pan/zoom basemaps.

## When Not To Use
- Geography isn't the insight: a sorted bar by region is clearer (chart-type-selection).
- A simple static location: use a static map image or a link to a maps app.
- 3D scenes unrelated to geography: 3d-web-three-and-r3f.

## Core Principles
1. **Choose the engine by need and license:**
   - MapLibre GL JS (BSD-3, open, WebGL vector maps, globe).
   - Leaflet (BSD-2, simple raster/DOM, tiny).
   - Mapbox GL JS v2+ (proprietary, requires a Mapbox account/token, usage-billed).
   - deck.gl (MIT, GPU data layers on top of a basemap).
2. **Maps are client-only.** They need `window`, WebGL, and DOM, so use `'use client'`, plus `next/dynamic` with `ssr: false` for libraries touching `window` at import (Leaflet).
3. **Data layers on the GPU, not DOM markers**, for more than a few hundred points (GeoJSON source + circle/symbol layer, or deck.gl).
4. **Normalize choropleths** (per capita, rate, density). Raw counts just map population.
5. **Attribution is mandatory.** Follow tile-provider terms. OSM's volunteer tile servers are not for production app traffic.
6. **Maps need a non-map alternative:** a list/table of places or regions that is searchable and keyboard-operable.

## Best Practices
- **Basemaps:**
  - Use a commercial vector tile provider (MapTiler, Stadia, Esri, Mapbox, etc.) or self-host PMTiles (Protomaps) on object storage/CDN.
  - Put provider API keys in env vars exposed to the client only when the provider restricts them by domain/referrer. Never expose secrets.
- **MapLibre:**
  - Add data as a `geojson` source with `cluster: true` for points. Style with data-driven expressions.
  - Update with `source.setData()`; don't re-create layers.
  - `promoteId` for feature-state hover. `map.getCanvas()` for export.
- **Clustering:** MapLibre/Mapbox built-in clustering, or supercluster for custom React markers.
- **DOM markers** (`<Marker>`): only for fewer than about 100–200 interactive pins (they're HTML elements).
- **deck.gl:** ScatterplotLayer/HexagonLayer/HeatmapLayer/ArcLayer for 100k–millions of points. v9.4 includes WebGPU parity for official layers and `@deck.gl/maplibre` integration. Pass binary attributes for large data.
- **Choropleth:** classed sequential palette (5–7 classes, quantile or natural breaks), a legend with class ranges, neutral "no data" hatch/gray, and a diverging palette only around a meaningful midpoint.
- **Projections:** Web Mercator distorts area at high latitudes. For global area comparisons, use equal-area projections (d3-geo static maps) or globe view (MapLibre v5+).
- **Viewport state** in the URL (`?lat&lng&z`) for shareable views. Debounce `moveend` updates.
- **Fit bounds** to data on load with padding. Respect `prefers-reduced-motion` (use `jumpTo` instead of `flyTo`).
- **Geocoding/search:** debounced combobox with keyboard support. Show attribution for the geocoder.
- **Mobile:** two-finger pan (`cooperativeGestures`) when the map is embedded in a scrolling page, so it doesn't trap scroll.

## Implementation Guidance
**Engine selection**

| Need | Choose | Notes |
|---|---|---|
| Open-source vector maps, styling, globe, 3D terrain | MapLibre GL JS (v5 introduced globe; v6 released mid-2026) + react-map-gl `react-map-gl/maplibre` | BSD-3; bring your own tiles |
| Simple raster map, few markers, tiny bundle | Leaflet 1.9.4 + react-leaflet | Leaflet 2.0 is still alpha (ESM, no `L` global, pointer events) |
| Mapbox-specific features/data (Standard style, Mapbox services) | Mapbox GL JS v3 | Proprietary license, token, billed map loads |
| 100k–millions of points, arcs, hexbins, GPU aggregation | deck.gl 9.4 over MapLibre (`@deck.gl/maplibre` / `MapboxOverlay`) | WebGL2/WebGPU |
| Static thematic map (report, print, SSR) | d3-geo + TopoJSON rendered to SVG | Server-renderable, accessible SVG |
| Choropleth inside a chart dashboard | ECharts `geo`/`map` series | Needs GeoJSON registration |

**Point count → rendering**

| Points | Approach |
|---|---|
| < 200 | DOM markers OK (accessible buttons) |
| 200–50k | GeoJSON source + circle/symbol layer, clustering |
| 50k–1M | vector tiles of the data, or deck.gl ScatterplotLayer with binary attributes |
| > 1M | server-side tiling (MVT/PMTiles) or deck.gl GPU aggregation, Arrow/binary transport |

## Recommended Workflow
1. Confirm geography is the insight. Define the non-map alternative (list/table).
2. Choose the engine and tile provider. Review license, pricing, and attribution requirements.
3. Create a client-only `Map` component with a fixed-height container. In Next.js, dynamic import if needed.
4. Load data (GeoJSON/vector tiles). Add sources and layers with data-driven styles.
5. Add interactions: hover feature-state, click popup/side panel, and clustering.
6. Sync viewport and selection with the URL. Link the list and map selection both ways.
7. Accessibility: keyboard controls, list alternative, focus management for popups.
8. Performance: test with production-size data on a mid-range phone.
9. CSP: allow tile/style/glyph origins and `worker-src blob:` if the library uses blob workers.

## Patterns
- **Map + synchronized list:** selecting in the list flies to and highlights the feature, and clicking the map focuses the list item.
- **Clustered GeoJSON source** with a cluster count symbol layer and click-to-zoom (`getClusterExpansionZoom`).
- **Feature-state hover** (no re-render): `map.setFeatureState({ source, id }, { hover: true })`.
- **deck.gl overlay:** `new MapboxOverlay({ interleaved: true, layers })` added as a MapLibre control, or `<DeckGL>` with `<Map>` child in React.
- **Static SVG choropleth** (d3-geo) in a Server Component with a table alternative.
- **Bounding-box queries:** fetch data for the current viewport on `moveend` (debounced, abortable).

## Anti-Patterns
- **Importing Leaflet in a Server Component or at module top in pages.** `window is not defined`. Fix: `'use client'` + `dynamic(() => import('./LeafletMap'), { ssr: false })`.
- **Thousands of React `<Marker>` components.** DOM explosion. Fix: GeoJSON layer + clustering, or deck.gl.
- **Using `tile.openstreetmap.org` for a production app.** Violates the OSM tile usage policy. Fix: a commercial provider or self-hosted tiles.
- **Upgrading to Mapbox GL JS v2+ assuming it's still open source.** License and billing surprise. Fix: MapLibre, or budget and comply with Mapbox terms.
- **Choropleth of raw counts / rainbow ramps.** Fix: normalize, use a sequential palette with class legend.
- **Re-creating the map on every React render.** Flicker and leaks. Fix: create once, update sources imperatively, and `map.remove()` on unmount.
- **Scroll-jacking embedded maps.** Fix: `cooperativeGestures` or scroll-zoom disabled until focus/click.
- **`flyTo` animations ignoring reduced motion.** Fix: `jumpTo` when reduced motion is set.
- **Missing attribution control.** Fix: keep the attribution control visible (compact is fine).

## Accessibility
- A map canvas is not accessible by itself. Provide the list/table alternative with the same data and actions (WCAG 1.1.1, 2.1.1).
- Keyboard: map container focusable (`tabIndex=0`, `aria-label="Map of stores, use arrow keys to pan, plus/minus to zoom"`). MapLibre's keyboard handler supports arrows and +/−. Zoom and locate buttons are real buttons with labels.
- Markers: DOM markers as `<button aria-label="Store: Downtown, open until 9pm">`. For GL layers, the list is the operable alternative.
- Popups: move focus into the popup on open, return it on close, and Esc closes.
- Color: choropleth classes distinguishable by lightness. Legend includes numeric ranges and a no-data pattern.
- Don't trap focus or scroll inside the map. Provide "Skip map" links for long pages.
- Announce result counts on viewport search politely ("24 stores in view").

## Responsive Design
- Container height via CSS (`height: min(60vh, 520px)`), with a full-screen toggle on mobile.
- Mobile layout: map with a draggable bottom sheet list (see drawers-and-sheets). Desktop: split view.
- Bigger touch targets for markers/clusters (≥24px, ideally 44px).
- Reduce label density and data detail at small viewports and low zooms.

## Performance
- WebGL maps: keep sources few and layers efficient. Use `setData` instead of layer churn. Simplify geometries (mapshaper) and use TopoJSON/vector tiles for large polygons.
- Code-split map bundles (MapLibre ~200KB+ gzipped class). Lazy-load below the fold or on interaction ("Show map" button with static preview image).
- deck.gl: binary attributes / Arrow tables avoid per-object JS overhead. GPU aggregation for hexbins/heatmaps.
- Avoid React state updates on every `move` event. Use `moveend` and refs.
- Limit devicePixelRatio on low-end devices if frame rate suffers (`pixelRatio` option).

## Security
- Map provider tokens in the browser are public: restrict them by URL/referrer in the provider dashboard, and use scoped, rotatable tokens. Never put secret keys in `NEXT_PUBLIC_*`.
- Popups built from feature properties must escape content (React components, not `setHTML` with user data).
- Location data is personal data: minimize precision, get consent for geolocation (`navigator.geolocation` prompts), and avoid logging exact coordinates.
- CSP: `connect-src`/`img-src` for tile, style, and glyph hosts. `worker-src blob:` (MapLibre) or configure the CSP-compatible worker build.

## Testing
- **Unit:** GeoJSON transforms, classification breaks, bbox query builders.
- **Component:** list alternative, filters, and selection sync (mock the map module in jsdom, since WebGL isn't available).
- **E2E (Playwright, Chromium with GPU/SwiftShader):** map loads, clicking a list item updates the URL and shows the popup, keyboard zoom works. Screenshot with a fixed style and viewport (tiles can vary, so mock the tile server or use a local PMTiles fixture).
- **Performance:** production-size data on a throttled mobile profile.

## Tooling
- MapLibre GL JS (v6.x current, 2026; globe since v5) and react-map-gl (supports MapLibre via `react-map-gl/maplibre`; verify major version for React 19).
- Leaflet 1.9.4 stable (2.0 alpha) and react-leaflet (check React 19 compatible major).
- Mapbox GL JS v3 (proprietary, BSD-3 only up to v1.13).
- deck.gl 9.4 (WebGPU parity, `@deck.gl/maplibre`, React widgets).
- Protomaps PMTiles, tippecanoe (vector tiles), mapshaper (simplify), supercluster, turf.js (geo ops), d3-geo + topojson-client.

## Framework Notes
- **React (Vite SPA):** import react-map-gl/maplibre directly and import `maplibre-gl/dist/maplibre-gl.css`. Keep the map instance via `useMap`/ref, and control viewport with controlled or uncontrolled `viewState` (prefer uncontrolled plus `onMoveEnd` for performance).
- **Next.js (App Router):**
  - Map components are `'use client'`. Leaflet and some plugins touch `window` at import, so wrap them in `dynamic(() => import('./LeafletMap'), { ssr: false, loading: () => <MapSkeleton/> })` inside a client component (`ssr:false` isn't allowed directly in Server Components).
  - Import map CSS in the client component or root layout.
  - Fetch GeoJSON or place lists in Server Components, render the accessible list on the server, and pass data to the client map.
  - Static choropleths via d3-geo can be pure Server Components (SVG).
  - Env: `NEXT_PUBLIC_MAPTILER_KEY` only for domain-restricted keys.
  - Update CSP headers in `next.config` for tile/style origins and `worker-src blob:`.

## AI Agent Guidance
- DO confirm the license/provider (default to MapLibre + a commercial or self-hosted tile source) and keep attribution.
- DO render maps client-only (dynamic `ssr:false` for Leaflet), with a fixed-height container and cleanup on unmount.
- DO use GeoJSON layers + clustering or deck.gl for many points, and normalized sequential choropleths.
- DO ship a synchronized list/table alternative and keyboard controls.
- DON'T use OSM public tiles in production, expose unrestricted tokens, or render thousands of DOM markers.
- Before done: `next build` passes (no window errors), keyboard zoom/pan works, list ↔ map sync works, attribution visible, mobile scroll not trapped, CSP allows tiles.

## Examples
```tsx
// components/maps/StoreMap.tsx
'use client';
import { useMemo, useRef } from 'react';
import Map, { Source, Layer, NavigationControl, type MapRef, type LayerProps } from 'react-map-gl/maplibre';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { FeatureCollection, Point } from 'geojson';

type StoreProps = { id: string; name: string };
const clusters: LayerProps = { id: 'clusters', type: 'circle', filter: ['has', 'point_count'],
  paint: { 'circle-color': '#2a78d6', 'circle-radius': ['step', ['get', 'point_count'], 16, 50, 22, 200, 30], 'circle-stroke-width': 2, 'circle-stroke-color': '#fff' } };
const count: LayerProps = { id: 'count', type: 'symbol', filter: ['has', 'point_count'],
  layout: { 'text-field': ['get', 'point_count_abbreviated'], 'text-size': 12 }, paint: { 'text-color': '#fff' } };
const points: LayerProps = { id: 'points', type: 'circle', filter: ['!', ['has', 'point_count']],
  paint: { 'circle-color': '#2a78d6', 'circle-radius': 7, 'circle-stroke-width': 2, 'circle-stroke-color': '#fff' } };

export function StoreMap({ stores, styleUrl, onSelect }: {
  stores: FeatureCollection<Point, StoreProps>; styleUrl: string; onSelect: (id: string) => void;
}) {
  const ref = useRef<MapRef>(null);
  const reduced = typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  const data = useMemo(() => stores, [stores]);

  return (
    <div style={{ height: 'min(60vh, 520px)' }}>
      <Map
        ref={ref}
        mapStyle={styleUrl}
        initialViewState={{ longitude: -98, latitude: 39, zoom: 3 }}
        cooperativeGestures
        interactiveLayerIds={['clusters', 'points']}
        onClick={async e => {
          const f = e.features?.[0];
          if (!f) return;
          if (f.properties?.cluster_id !== undefined) {
            const src = ref.current?.getSource('stores') as unknown as { getClusterExpansionZoom(id: number): Promise<number> };
            const zoom = await src.getClusterExpansionZoom(f.properties.cluster_id);
            const [lng, lat] = (f.geometry as Point).coordinates;
            reduced ? ref.current?.jumpTo({ center: [lng, lat], zoom }) : ref.current?.easeTo({ center: [lng, lat], zoom });
          } else if (f.properties?.id) onSelect(String(f.properties.id));
        }}
        aria-label="Map of stores. Arrow keys pan, plus and minus zoom. A list of stores follows the map."
      >
        <NavigationControl position="top-right" />
        <Source id="stores" type="geojson" data={data} cluster clusterMaxZoom={14} clusterRadius={50} promoteId="id">
          <Layer {...clusters} /><Layer {...count} /><Layer {...points} />
        </Source>
      </Map>
    </div>
  );
}
```
```tsx
// app/stores/StoreMapClient.tsx: client wrapper enabling dynamic import
'use client';
import dynamic from 'next/dynamic';
export const StoreMapLazy = dynamic(() => import('@/components/maps/StoreMap').then(m => m.StoreMap), {
  ssr: false,
  loading: () => <div style={{ height: 'min(60vh, 520px)' }} aria-hidden className="animate-pulse bg-muted" />,
});
```
Render the accessible `<ul>` of stores in the Server Component page, next to `<StoreMapLazy>`.

## Related Skills
- [chart-type-selection](../chart-type-selection/Skill.md): when a map is the right form
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md): deck.gl, binary data
- [d3-fundamentals](../d3-fundamentals/Skill.md): d3-geo static maps
- [drawers-and-sheets](../drawers-and-sheets/Skill.md): mobile map + list sheet
- [content-security-policy](../content-security-policy/Skill.md): tile/worker origins
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md): public tokens
- [search-and-autocomplete](../search-and-autocomplete/Skill.md): geocoding search
- [accessible-data-visualization](../accessible-data-visualization/Skill.md)

## Sources
- [MapLibre news](https://maplibre.org/news/): Official; v5/v6 releases, globe, 2026 status
- [MapLibre GL JS releases](https://github.com/maplibre/maplibre-gl-js/releases): Official; v6.x features (globe+terrain, keyboard-accessible draggable markers, RTL plugin deprecation)
- [Mapbox GL JS LICENSE](https://github.com/mapbox/mapbox-gl-js/blob/main/LICENSE.txt): Official; proprietary from v2, BSD-3 through v1.13
- [Leaflet releases](https://github.com/Leaflet/Leaflet/releases): Official; 1.9.4 stable, 2.0 alpha breaking changes
- [deck.gl what's new](https://deck.gl/docs/whats-new) and [releases](https://github.com/visgl/deck.gl/releases): Official; 9.4 WebGPU, `@deck.gl/maplibre`, widgets
- [FT Visual Vocabulary: Spatial](https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary): Community; spatial chart forms

## License / Usage Notes
MapLibre (BSD-3), Leaflet (BSD-2), deck.gl (MIT), react-map-gl (MIT), react-leaflet (Hippocratic License 2.1 in recent versions, so verify suitability). Mapbox GL JS v2+ is proprietary. Basemap tiles and data (OSM ODbL) require attribution. The exact MapLibre v6 breaking changes and react-map-gl/react-leaflet versions were not verified this cycle. Content is summarized. Code is original.

## Quality Tier
B: Engine, licensing, and version landscape verified. Wrapper versions and some MapLibre v6 API details need confirmation.

## Status
Active

## Last Verified
2026-09-15
