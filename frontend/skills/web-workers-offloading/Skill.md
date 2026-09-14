# Web Workers Offloading

## Summary
Web Workers run JavaScript on background threads, off the main thread, so heavy computation doesn't block input or rendering. Typical workloads are parsing, sorting and filtering large datasets, search indexing, diffing, image processing, crypto, compression, WASM and OffscreenCanvas rendering. Workers have no DOM access and communicate by message passing, so the design question is what to move and how to keep messaging cheap. In React + Next.js, create module workers with `new Worker(new URL('./x.worker.ts', import.meta.url), { type: 'module' })`, wrap them with Comlink for an async-function API, and manage their lifecycle in hooks.

## Category
Performance

## Subcategories
Dedicated workers, module workers, Comlink, transferables, structured clone, OffscreenCanvas, SharedArrayBuffer and cross-origin isolation, WASM, worker pools, React hooks for workers

## Problem It Solves
Long tasks from CPU-bound work block input (poor INP) and cause UI freezes. Examples: filtering 100k rows, parsing large CSV/JSON, fuzzy search, Markdown rendering of large documents, image resizing before upload, chart data aggregation. Yielding only spreads the work out; a worker moves it off the main thread entirely.

## When To Use
- A pure computation takes more than ~50 ms on mid-tier mobile and runs during interaction or load.
- A computation repeats often: search-as-you-type over big indexes, live data aggregation.
- Image, video or audio processing, compression, or hashing of user files.
- Canvas rendering that can use OffscreenCanvas (charts, visualizations).

## When Not To Use
- The work needs the DOM or React state directly. Workers can't touch the DOM.
- Small or quick tasks. Message and clone overhead outweighs the benefit.
- The work can be done on the server. In Next.js, Server Components or Route Handlers are often better for heavy data transforms ([react-server-components](../react-server-components/Skill.md)).
- Third-party script offloading has its own trade-offs: see [third-party-script-management](../third-party-script-management/Skill.md) (Partytown).

## Core Principles
1. **Move pure, CPU-bound work.** Keep UI and DOM on the main thread.
2. **Minimize data crossing the boundary.** Send IDs, deltas or transferables. Structured clone of large objects is itself a main-thread cost.
3. **Keep the worker warm.** Create it once (lazily), reuse it, and terminate it when no longer needed.
4. **Cancel stale work.** For search-as-you-type, ignore or abort outdated results.
5. **Measure before and after.** Main-thread long tasks should disappear, and end-to-end latency must stay acceptable.

## Best Practices
- Use module workers (`type: 'module'`) with the `new URL(..., import.meta.url)` pattern. Vite, webpack 5 and Turbopack recognize it and bundle the worker. Verify on your Next.js version.
- Wrap workers with Comlink (`expose`/`wrap`) to get typed async calls instead of manual `postMessage` switch statements.
- Transfer `ArrayBuffer`, `ImageBitmap`, `OffscreenCanvas` and `MessagePort` with `transfer` lists (`Comlink.transfer`) to avoid copying.
- Keep large datasets inside the worker: load or fetch them there, and query with small messages.
- Create workers client-side only: in effects or event handlers, never at module scope in files that render on the server.
- Use a small pool (e.g., `navigator.hardwareConcurrency - 1`, capped at 2–4) only for embarrassingly parallel work.
- `SharedArrayBuffer`/`Atomics` require cross-origin isolation (`Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` or `credentialless`). This can break third-party embeds, so adopt it deliberately.
- Handle errors: `worker.onerror`, or rejected promises through Comlink. Surface failures to the UI.

## Implementation Guidance

### Decision table
| Workload | Worker? | Notes |
|---|---|---|
| Filter/sort 50k+ rows client-side | Yes | Keep dataset in worker; return visible page of IDs/rows |
| Fuzzy search index (e.g., FlexSearch/MiniSearch) | Yes | Build index in worker once |
| CSV/XLSX parsing of uploads | Yes | Transfer file `ArrayBuffer` |
| Markdown → HTML for large docs | Yes (client) / Prefer server in Next.js | Sanitize output |
| Image resize/compress before upload | Yes | `OffscreenCanvas` / `createImageBitmap` in worker |
| Chart rendering on canvas | Yes with OffscreenCanvas | Transfer canvas via `transferControlToOffscreen()` |
| Form validation (zod) | No | Fast; overhead dominates |
| React rendering | No | Use transitions/virtualization |
| Heavy transform of server data in Next.js | Prefer server | Zero client cost |

### Worker with Comlink (shared by Vite and Next.js)
```ts
// src/workers/search.worker.ts
import * as Comlink from 'comlink';
import MiniSearch from 'minisearch';

type Doc = { id: string; title: string; body: string };
let index: MiniSearch<Doc> | null = null;

const api = {
  async build(url: string) {
    const docs: Doc[] = await (await fetch(url)).json();          // data stays in the worker
    index = new MiniSearch<Doc>({ fields: ['title', 'body'], storeFields: ['title'] });
    index.addAll(docs);
    return docs.length;
  },
  search(q: string, limit = 20) {
    if (!index) return [];
    return index.search(q, { prefix: true, fuzzy: 0.2 }).slice(0, limit).map((r) => ({ id: r.id as string, title: r.title as string }));
  },
};
export type SearchApi = typeof api;
Comlink.expose(api);
```

```tsx
// src/hooks/use-search-worker.ts
'use client';
import { useEffect, useRef, useState } from 'react';
import * as Comlink from 'comlink';
import type { SearchApi } from '@/workers/search.worker';

export function useSearchWorker(indexUrl: string) {
  const apiRef = useRef<Comlink.Remote<SearchApi> | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const worker = new Worker(new URL('../workers/search.worker.ts', import.meta.url), { type: 'module' });
    const api = Comlink.wrap<SearchApi>(worker);
    apiRef.current = api;
    api.build(indexUrl).then(() => setReady(true)).catch(console.error);
    return () => { apiRef.current = null; worker.terminate(); };   // lifecycle tied to component
  }, [indexUrl]);

  return { ready, search: (q: string) => apiRef.current?.search(q) ?? Promise.resolve([]) };
}
```

```tsx
// Search box: ignore stale responses
'use client';
import { useEffect, useState } from 'react';
import { useSearchWorker } from '@/hooks/use-search-worker';

export function SiteSearch() {
  const { ready, search } = useSearchWorker('/search-index.json');
  const [q, setQ] = useState('');
  const [results, setResults] = useState<{ id: string; title: string }[]>([]);

  useEffect(() => {
    let stale = false;
    if (!q) { setResults([]); return; }
    search(q).then((r) => { if (!stale) setResults(r); });
    return () => { stale = true; };
  }, [q, search]);

  return (
    <div role="search">
      <input value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search docs" disabled={!ready} />
      <ul aria-live="polite">{results.map((r) => <li key={r.id}>{r.title}</li>)}</ul>
    </div>
  );
}
```
In production, memoize `search` (`useCallback`) or rely on the React Compiler, so the effect isn't re-triggered on every render.

### Transferables: image resize before upload
```ts
// resize.worker.ts
import * as Comlink from 'comlink';
Comlink.expose({
  async resize(file: Blob, maxWidth: number) {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, maxWidth / bitmap.width);
    const canvas = new OffscreenCanvas(Math.round(bitmap.width * scale), Math.round(bitmap.height * scale));
    canvas.getContext('2d')!.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    return canvas.convertToBlob({ type: 'image/webp', quality: 0.8 });
  },
});
```

### Vite-specific import (alternative)
```ts
import SearchWorker from './search.worker.ts?worker';   // Vite only
const worker = new SearchWorker();
```
Prefer the `new URL()` form in code shared with Next.js.

## Recommended Workflow
1. Profile the interaction or load. Identify the long task's function and confirm it's pure computation.
2. Extract the computation into a module with no DOM or React dependencies. Unit-test it.
3. Move it into a worker with Comlink. Keep data in the worker and design small request/response messages.
4. Integrate through a hook with lazy creation, cleanup, stale-result handling, and error states.
5. Re-profile: no long tasks on the main thread for the scenario, INP improved, and total latency (including messaging) acceptable.
6. Test on low-end devices. Worker startup and data transfer costs are higher there.

## Patterns
- **Data-owning worker:** the dataset lives in the worker and the UI queries it.
- **Latest-wins queries:** a stale flag or request IDs.
- **Worker singleton module:** one worker shared across components via a context or module-level lazy getter (client-only).
- **OffscreenCanvas rendering:** the main thread only handles input; the worker draws.
- **WASM in worker:** heavy codecs or compute without blocking the UI.

## Anti-Patterns
- **Sending the whole dataset to the worker on every keystroke.** Clone cost blocks the main thread. Fix: load once in the worker.
- **Creating a new worker per call.** Startup overhead. Fix: reuse, and terminate on unmount.
- **Instantiating `Worker` at module scope in a file imported by Server Components or SSR.** `Worker is not defined` errors. Fix: create in effects or handlers inside Client Components.
- **Moving DOM-dependent code into workers.** Fails. Fix: split pure logic from DOM updates.
- **Enabling COOP/COEP globally just to try SharedArrayBuffer.** Breaks OAuth popups and embeds. Fix: only when needed, tested.
- **No error handling.** Silent failures. Fix: catch, and show an error state.

## Accessibility
- Show progress and busy states for long worker jobs (`aria-busy`, progress bar with `aria-valuenow`) and announce completion politely ([live-regions-and-announcements](../live-regions-and-announcements/Skill.md)).
- Offloading keeps keyboard and screen-reader interaction responsive during heavy work, which matters for AT users.
- Don't disable inputs indefinitely if the worker fails. Provide a fallback or an error message.

## Responsive Design
- Low-end phones have fewer cores. Cap pools at 1–2 workers there (`navigator.hardwareConcurrency`), and consider server-side processing for very large jobs.

## Performance
- Worker startup costs tens of ms (parse and execute of the worker bundle). Create lazily on first need, or on idle if likely needed.
- Structured clone scales with data size and object complexity. Transferables are near zero-copy.
- Workers don't make work faster, only parallel. Total CPU time and battery use stay similar.

## Security
- Worker scripts follow CSP `worker-src` (falls back to `script-src`/`child-src`). Keep them same-origin ([content-security-policy](../content-security-policy/Skill.md)).
- Validate messages if workers accept data from `MessagePort`s exposed to other contexts.
- Sanitize any HTML produced in workers (e.g., Markdown) before rendering. Workers don't make output safe.
- Cross-origin isolation headers have security benefits but can break integrations. Plan and test them.

## Testing
- Unit-test pure computation modules directly in Vitest (no worker needed).
- Integration: Vitest browser mode or Playwright to exercise the real worker path.
- Mock the worker hook in component tests, returning deterministic results.
- Performance regression: Playwright trace or CDP check that no main-thread task over 50 ms occurs during the scenario.

## Tooling
- Web Workers, module workers, OffscreenCanvas: Baseline.
- Comlink (GoogleChromeLabs): Stable, low-churn. Check recent activity before adopting; the API is small and stable.
- MiniSearch / FlexSearch: Active (in-worker search).
- Vite `?worker` imports and `new URL()` worker bundling: Active.
- webpack 5 / Turbopack `new Worker(new URL(...))` support: Active (verify per Next.js version).

## Framework Notes
- **React (Vite SPA):**
  - First-class support via `new URL()` or `?worker`.
  - Integrate with TanStack Query by using worker calls as `queryFn` for derived data caching.
  - Keep worker files free of React imports.
- **Next.js:**
  - Workers are client-only: use them in Client Components and hooks, and guard against SSR.
  - Decide first whether the computation belongs on the server (Server Component, Route Handler, Server Action). That removes client cost entirely.
  - Use workers for user-local data (uploaded files, offline datasets, real-time streams) or latency-sensitive interactivity.
  - Static index files for workers can go in `public/` or be fetched from Route Handlers with caching.

## AI Agent Guidance
- Do: confirm the long task is pure computation. Consider server-side processing first in Next.js.
- Do: use the Comlink + `new URL(..., import.meta.url)` module worker pattern, with lazy creation, `terminate()` on cleanup, stale-result handling and error states.
- Don't: move DOM or React logic into workers, instantiate workers at module scope in SSR-reachable code, or clone large data per message.
- Before declaring done: the trace shows the long task gone from the main thread, results are correct (unit tests pass on the pure module), the worker terminates on unmount, and CSP allows the worker.

## Examples
```ts
// Transfer an ArrayBuffer with Comlink
import * as Comlink from 'comlink';
const buf = await file.arrayBuffer();
const rows = await parserApi.parseCsv(Comlink.transfer(buf, [buf])); // buf is detached on main thread after transfer
```

## Related Skills
- [inp-optimization](../inp-optimization/Skill.md): when yielding isn't enough
- [rendering-performance](../rendering-performance/Skill.md): main-thread rendering work
- [large-dataset-visualization-performance](../large-dataset-visualization-performance/Skill.md): OffscreenCanvas charts
- [file-upload](../file-upload/Skill.md): client-side processing of uploads
- [search-and-autocomplete](../search-and-autocomplete/Skill.md): search UX with worker-backed indexes
- [browser-apis-in-react](../browser-apis-in-react/Skill.md): integrating browser APIs in hooks
- [third-party-script-management](../third-party-script-management/Skill.md): Partytown worker offload for tags

## Sources
- [MDN: Using Web Workers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers) (Official): worker model, module workers, messaging
- [MDN: Transferable objects](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Transferable_objects) (Official): zero-copy transfers
- [Comlink](https://github.com/GoogleChromeLabs/comlink) (Open Source): RPC wrapper, `transfer`
- [Vite: Web Workers](https://vite.dev/guide/features#web-workers) (Official): `new URL()` and `?worker` imports
- [web.dev: Use web workers to run JavaScript off the main thread](https://web.dev/articles/off-main-thread) (Official): off-main-thread architecture
- [MDN: OffscreenCanvas](https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas) (Official): worker rendering
- [web.dev: COOP/COEP cross-origin isolation](https://web.dev/articles/coop-coep) (Official): SharedArrayBuffer requirements

## License / Usage Notes
Summarized. Comlink Apache-2.0, MiniSearch MIT. Examples original.

## Quality Tier
A: Stable platform APIs with React/Next integration patterns. Turbopack worker bundling should be verified per Next.js release.

## Status
Active

## Last Verified
2026-09-15
