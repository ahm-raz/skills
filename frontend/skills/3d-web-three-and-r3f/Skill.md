# 3D on the Web: three.js and React Three Fiber

## Summary
three.js is the dominant WebGL/WebGPU 3D library for the web. React Three Fiber (R3F) is a React renderer for three.js that expresses scenes as JSX with hooks (`useFrame`, `useThree`, `useLoader`). drei provides a large helper library (controls, loaders, environment, text, HTML overlays, performance utilities). As of September 2026, `@react-three/fiber@9` pairs with React 19 (v8 with React 18). three.js ships `WebGPURenderer` (from `three/webgpu`) with a WebGL2 fallback and the TSL shader language. This skill covers integrating 3D into React/Next.js apps performantly and accessibly.

## Category
Animation

## Subcategories
WebGL, WebGPU, React Three Fiber, drei, 3D product viewers, hero scenes, shaders, GLTF models, performance scaling, postprocessing

## Problem It Solves
Product configurators, interactive hero scenes, data-driven 3D, and immersive marketing experiences need real-time 3D. Raw three.js in React leads to imperative spaghetti, memory leaks, and duplicate render loops. R3F provides declarative scene graphs, automatic disposal, and React integration, but it needs discipline around the render loop, assets, and SSR.

## When To Use
- 3D product viewers/configurators (e-commerce), interactive hero sections, data visualization in 3D.
- Scenes needing interactivity tied to React state (selection, UI overlays).
- Shader-based visual effects where CSS/SVG isn't enough.

## When Not To Use
- Decorative depth effects achievable with CSS 3D transforms, images, or video.
- Content-critical pages where LCP and low-end device performance matter more than visual flair. Use a pre-rendered image or video.
- When the team lacks 3D asset pipeline capacity (optimized GLTF, textures). A poorly optimized model can be 50MB.
- Simple 2D motion: use CSS/Motion.

## Core Principles
1. Mutate in `useFrame` via refs, never `setState` per frame.
2. Render on demand (`frameloop="demand"`) for static or interaction-driven scenes, and call `invalidate()` on change.
3. Optimize assets: GLTF/GLB with Draco or Meshopt compression, KTX2 textures, reasonable polycounts.
4. Reuse geometries/materials, instance repeated objects, and use LOD for distance.
5. Adapt quality to device: cap DPR (`dpr={[1, 2]}`), use `PerformanceMonitor` to regress quality.
6. Canvas is client-only. Isolate it in a `"use client"` component and lazy-load it with a poster.
7. Provide non-3D fallbacks and accessible alternatives for the information in the scene.

## Best Practices
- Pair versions correctly: R3F 9 ↔ React 19; drei and postprocessing versions compatible with that major.
- Convert models with `gltfjsx` (`npx gltfjsx model.glb --transform`) to get typed JSX components plus compressed assets. Run it locally as a dev tool; review generated code.
- Use `useGLTF.preload(url)` for assets needed immediately, and `Suspense` with a lightweight fallback.
- Use drei `<Bounds>`/`<Center>` for framing, `<Environment preset>` for lighting (preset HDRs load from a CDN, so self-host files for production/CSP).
- Use `<AdaptiveDpr pixelated />` and `<AdaptiveEvents />` or `PerformanceMonitor` + `regress()` during interaction.
- Pause rendering offscreen: set `frameloop="never"` when not intersecting, or unmount the Canvas below the fold.
- Dispose: R3F auto-disposes objects it creates. Manually created resources (via `new` in effects) need `.dispose()`.
- Use `<Html>` from drei sparingly; each overlay is a DOM element synced per frame.
- Prefer `meshStandardMaterial`/`meshPhysicalMaterial` with baked lighting for performance on mobile.

## Implementation Guidance

### Install
```bash
npm install three @react-three/fiber @react-three/drei
npm install -D @types/three
```
Next.js: add `transpilePackages: ["three"]` in `next.config.ts` if you hit ESM or transpile issues with three examples.

### Decision table
| Need | Approach |
|---|---|
| Rotating product with orbit controls | R3F + drei `OrbitControls`, `Stage`/`Environment`, `frameloop="demand"` |
| Scroll-linked 3D hero | R3F + drei `ScrollControls` or Motion `useScroll` → ref mutation |
| 10k repeated objects | `InstancedMesh` / drei `<Instances>` |
| Custom visual effect | ShaderMaterial / TSL node materials (WebGPU) |
| Postprocessing (bloom, DOF) | `@react-three/postprocessing` (costly on mobile; gate) |
| Physics | `@react-three/rapier` |
| Vanilla non-React widget | three.js directly in a ref + effect with full disposal |

### Renderer choice (Sept 2026)
| Renderer | Notes |
|---|---|
| `WebGLRenderer` (R3F default) | Broadest compatibility; most drei/postprocessing support |
| `WebGPURenderer` (`three/webgpu`) | WebGPU with automatic WebGL2 fallback; TSL shaders; async init. Pass a custom `gl` factory to `<Canvas>`; verify drei/postprocessing compatibility per helper |

### Performance targets
| Metric | Mobile target | Desktop target |
|---|---|---|
| Draw calls | < 100 | < 500 |
| Triangles on screen | < 100k | < 1M |
| Texture memory | < 100MB | < 500MB |
| GLB transfer size (hero) | < 2–5MB | < 10MB |
| DPR cap | 1.5–2 | 2 |

## Recommended Workflow
1. Define the purpose and fallback (static render image or video) before building.
2. Optimize assets: `gltf-transform`/`gltfjsx --transform` (Draco/Meshopt, KTX2/WebP, resize).
3. Build a client `Scene` component with `<Canvas>`, Suspense fallback, and controls.
4. Configure `frameloop`, `dpr`, and `PerformanceMonitor`.
5. Integrate with the page via `next/dynamic`, with a poster image and an explicit container size.
6. Add reduced-motion (no auto-rotation or camera fly-throughs) and accessible descriptions.
7. Profile with `r3f-perf` or `stats-gl` in development, and on a real mid-range phone. Check GPU memory and draw calls.

## Patterns

### Client scene with on-demand rendering
```tsx
// components/three/product-viewer.tsx
"use client";
import { Canvas } from "@react-three/fiber";
import { OrbitControls, Environment, useGLTF, Bounds } from "@react-three/drei";
import { Suspense } from "react";

function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url);
  return <primitive object={scene} />;
}

export default function ProductViewer({ url, label }: { url: string; label: string }) {
  return (
    <div className="aspect-square w-full" role="img" aria-label={label}>
      <Canvas frameloop="demand" dpr={[1, 2]} camera={{ position: [0, 0, 3], fov: 45 }}>
        <Suspense fallback={null}>
          <Bounds fit clip observe margin={1.2}>
            <Model url={url} />
          </Bounds>
          <Environment files="/hdr/studio_small.hdr" />
        </Suspense>
        <OrbitControls makeDefault enablePan={false} />
      </Canvas>
    </div>
  );
}
```
`OrbitControls` with `makeDefault` invalidates on change automatically in demand mode.

### Lazy-load from a Server Component page
```tsx
// components/three/product-viewer-lazy.tsx
"use client";
import dynamic from "next/dynamic";
export const ProductViewerLazy = dynamic(() => import("./product-viewer"), {
  ssr: false,
  loading: () => <img src="/products/chair-poster.webp" alt="" className="aspect-square w-full object-contain" />,
});
```
```tsx
// app/products/[slug]/page.tsx (Server Component)
import { ProductViewerLazy } from "@/components/three/product-viewer-lazy";
export default function Page() {
  return <ProductViewerLazy url="/models/chair.glb" label="3D model of the Oslo chair in oak" />;
}
```

### Per-frame animation without re-renders
```tsx
"use client";
import { useFrame } from "@react-three/fiber";
import { useRef } from "react";
import type { Mesh } from "three";

export function Spinner({ reduced }: { reduced: boolean }) {
  const ref = useRef<Mesh>(null);
  useFrame((_, delta) => {
    if (!reduced && ref.current) ref.current.rotation.y += delta * 0.5; // frame-rate independent
  });
  return (
    <mesh ref={ref}>
      <torusKnotGeometry args={[0.6, 0.2, 128, 16]} />
      <meshStandardMaterial color="#6366f1" />
    </mesh>
  );
}
```
`useFrame` requires `frameloop="always"`, or explicit `invalidate()` calls in demand mode.

### Adaptive quality
```tsx
import { PerformanceMonitor, AdaptiveDpr } from "@react-three/drei";
const [dpr, setDpr] = useState(1.5);
<Canvas dpr={dpr}>
  <PerformanceMonitor onIncline={() => setDpr(2)} onDecline={() => setDpr(1)} />
  <AdaptiveDpr pixelated />
</Canvas>
```

### Pause when offscreen
```tsx
const [visible, setVisible] = useState(true);
// IntersectionObserver on wrapper sets visible
<Canvas frameloop={visible ? "always" : "never"} />
```

### WebGPU renderer (verify helper compatibility)
```tsx
import * as THREE from "three/webgpu";
<Canvas gl={async (props) => { const r = new THREE.WebGPURenderer(props as any); await r.init(); return r; }} />
```

## Anti-Patterns
| Anti-pattern | Why | Fix |
|---|---|---|
| `setState` inside `useFrame` | React re-render at 60–120fps | Mutate refs |
| Creating geometries/materials in render | GPU uploads per render | Memoize or share at module scope |
| Uncompressed 30MB GLB hero | Slow LCP, mobile crashes | Draco/Meshopt + KTX2, poster first |
| `frameloop="always"` for static viewer | Battery/fan drain | `demand` + `invalidate` |
| Canvas imported in a Server Component | Build/runtime errors | `"use client"` + `next/dynamic ssr:false` in a client file |
| Many `<Canvas>` instances on a page | Multiple WebGL contexts (limit ~16) | One canvas with drei `View` / scissor |
| drei `Environment preset` in production | Fetches HDR from external CDN | Self-host `files` |
| Unbounded DPR on 3x phones | 9x pixel cost | `dpr={[1, 2]}` |
| Heavy postprocessing on mobile | Frame drops | Gate by `PerformanceMonitor` or device |
| Relying on 3D for essential info | Inaccessible, fails on no-WebGL | Text specs, images, fallback |

## Accessibility
- The canvas is opaque to assistive tech. Provide `role="img"` + `aria-label` for simple viewers, and mirror essential information (product details, selected options) in the DOM.
- Interactive 3D controls (color pickers, part selectors) should be HTML controls outside the canvas that drive scene state; keyboard accessible.
- `@react-three/a11y` can add focusable, announced 3D objects. Check maintenance status before adopting (community, historically low activity).
- WCAG 2.3.3: disable auto-rotation, camera fly-throughs, and parallax under reduced motion.
- WCAG 2.2.2: continuous animations over 5s need pause controls.
- Don't trap scroll/touch: orbit controls on mobile can block page scrolling. Require two-finger gestures, or disable zoom on scroll (`enableZoom={false}`) in page contexts.

## Responsive Design
- Size the canvas via CSS containers. R3F resizes with its parent; use aspect-ratio boxes.
- Adjust camera FOV/position by aspect (`useThree(s => s.viewport)`) so models fit portrait screens.
- Lower DPR, disable shadows and postprocessing on small or low-power devices.
- Provide a static image on devices without WebGL2, or when `navigator.connection?.saveData` is set.

## Performance
- The render loop runs on the main thread (WebGL command submission). Heavy scenes hurt INP for the whole page. Demand rendering and offscreen pausing are essential.
- Load three.js (~150KB+ gzip with drei pieces) only on pages or below-fold sections that need it via `next/dynamic`.
- `useLoader`/`useGLTF` cache assets by URL. Preload on intent (hover over the "View in 3D" button).
- Instancing and merged geometry reduce draw calls. Texture atlases reduce material count.
- `OffscreenCanvas` + worker rendering (`@react-three/offscreen`) can move rendering off the main thread; check maintenance and compatibility.
- Monitor GPU memory with `renderer.info` (`gl.info.memory`, `render.calls`).

## Security
- Treat user-uploaded models as untrusted. Validate size and type server-side, and set loader limits. Parsing huge files can crash tabs.
- Self-host decoders (Draco, Basis/KTX2 transcoder WASM) instead of loading from third-party CDNs by default. Adjust CSP (`wasm-unsafe-eval`, `worker-src blob:` if required).
- Don't pass untrusted strings into shader code.

## Testing
- Unit: extract scene logic (state → transforms) into pure functions. R3F provides `@react-three/test-renderer` for scene graph assertions without WebGL.
- E2E: Playwright in Chromium with GPU flags or SwiftShader. Screenshot comparisons need tolerance because rendering varies by GPU.
- Performance: `r3f-perf` or `stats-gl` overlays in development, the Spector.js extension for draw call inspection, and Chrome Performance traces for main-thread cost.
- Fallback tests: disable WebGL (`--disable-gpu`) and verify the poster and information remain.

## Tooling
- `three` (Active; r17x+ with `three/webgpu`) — MIT.
- `@react-three/fiber` 9 (Active; React 19) — MIT.
- `@react-three/drei` (Active) — helpers.
- `@react-three/postprocessing`, `@react-three/rapier` (Active).
- `gltfjsx`, `@gltf-transform/cli` (Active) — asset optimization.
- `r3f-perf`, `leva` (debug GUI) — development only.
- Spline (design tool with React export) — convenient but heavier runtime; evaluate performance.

## Framework Notes
- **React (Vite SPA)**: import `<Canvas>` directly. Lazy-load with `React.lazy` for below-fold scenes. Vite handles three ESM without config. Keep global UI state (Zustand, which is commonly used with R3F) outside the Canvas and subscribe via selectors inside `useFrame` (`useStore.getState()`) to avoid re-renders.
- **Next.js App Router**: `<Canvas>` and all R3F hooks require `"use client"`. Load the scene via `next/dynamic(..., { ssr: false })` declared inside a client file, and render a poster from the Server Component for LCP. Add `transpilePackages: ["three"]` if you import from `three/examples/jsm` and hit ESM issues. Serve `.glb`/`.hdr`/`.ktx2` from `public/` with long-lived cache headers. R3F Canvas lives in its own React root, so React context from the app doesn't automatically cross; pass props or re-provide contexts inside the Canvas.
- **Hydration**: with `ssr: false` there's no mismatch, but the swap from poster to canvas must keep identical dimensions (no CLS). Don't read `window.devicePixelRatio` during server render.

## AI Agent Guidance
- DO isolate 3D in client components loaded via `next/dynamic` with a poster and fixed aspect ratio.
- DO use `frameloop="demand"` unless continuous animation is required; cap DPR; mutate refs in `useFrame`.
- DO optimize and self-host assets and decoders; add reduced-motion handling.
- DON'T add 3D where an image/video suffices; DON'T create materials/geometries in render loops.
- DON'T run `npx gltfjsx` or other CLIs without user approval; suggest the command instead.
- Verify: page LCP isn't blocked by 3D; no console WebGL warnings; memory stable after navigating away and back; mobile frame rate acceptable; information available without WebGL.

## Examples

### Scroll-linked camera using Motion value (no re-renders)
```tsx
"use client";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { useScroll } from "motion/react";

function CameraRig() {
  const { scrollYProgress } = useScroll();
  const camera = useThree(s => s.camera);
  useFrame(() => {
    const p = scrollYProgress.get();
    camera.position.set(Math.sin(p * Math.PI) * 2, 1, 4 - p * 2);
    camera.lookAt(0, 0, 0);
  });
  return null;
}

export default function ScrollScene() {
  return (
    <Canvas className="!fixed inset-0 -z-10" dpr={[1, 1.5]}>
      <CameraRig />
      <ambientLight intensity={0.6} />
      <mesh><icosahedronGeometry args={[1, 1]} /><meshStandardMaterial flatShading /></mesh>
    </Canvas>
  );
}
```
Under reduced motion, render a static camera instead of `CameraRig`.

## Related Skills
- [animation-performance](../animation-performance/Skill.md) — main-thread and GPU costs
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — deferring three.js
- [lcp-optimization](../lcp-optimization/Skill.md) — posters for 3D heroes
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — product viewers
- [landing-page-design](../landing-page-design/Skill.md) — 3D hero usage
- [gsap-animation](../gsap-animation/Skill.md) — tweening scene values
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — camera motion risks
- [content-security-policy](../content-security-policy/Skill.md) — WASM decoders

## Sources
- [R3F installation](https://r3f.docs.pmnd.rs/getting-started/installation) — Official — v9↔React 19 pairing, Next.js transpilePackages
- [R3F scaling performance](https://r3f.docs.pmnd.rs/advanced/scaling-performance) — Official — demand frameloop, instancing, LOD, PerformanceMonitor, regress
- [drei docs](https://drei.docs.pmnd.rs/) — Official/Open Source — helpers (OrbitControls, Environment, Bounds, AdaptiveDpr)
- [three.js docs](https://threejs.org/docs/) — Official — WebGPURenderer, loaders
- [Motion changelog (motion/three effects, 13.2)](https://motion.dev/changelog) — Official — emerging Motion↔three.js integration

## License / Usage Notes
three.js, R3F, and drei are MIT. HDRIs and models have their own licenses (e.g. Poly Haven CC0). Content summarized; code original.

## Quality Tier
B — R3F docs verified. WebGPU-with-R3F details and three.js revision numbers weren't verified directly this session (the three.js manual page 404'd), so treat the WebGPU pattern as needing verification.

## Status
Active

## Last Verified
2026-09-15
