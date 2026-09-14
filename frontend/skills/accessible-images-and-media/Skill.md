# Accessible Images and Media

## Summary
Providing text alternatives for images, icons, SVGs and charts, and captions, transcripts and audio description for audio and video, in React/Next.js. Covers the alt-text decision tree, `next/image`, inline SVG patterns, complex images, `<video>`/`<track>`, player controls, autoplay rules and AI-generated alt text. Missing alt text affected 53.1% of home pages in the WebAIM Million 2026.

## Category
Accessibility

## Subcategories
Alt text, decorative images, SVG accessibility, icon accessibility, complex images, next/image, captions, subtitles, transcripts, audio description, video players, images of text

## Problem It Solves
Blind and low-vision users hear "image", file names ("IMG_2031.jpg"), or nothing for meaningful images, and redundant noise for decorative ones. Deaf and hard-of-hearing users miss uncaptioned video. Autoplaying media disrupts screen readers. All are basic, high-frequency WCAG failures (1.1.1, 1.2.x, 1.4.2, 1.4.5).

## When To Use
- Any `<img>`, `next/image`, CSS background image with meaning, SVG, icon, chart, avatar, logo or illustration.
- Any audio, video, podcast, livestream, animated GIF, or embedded player.

## When Not To Use
- Data visualisations need more than alt text (see accessible-data-visualization), though the text-alternative basics here apply.

## Core Principles
1. **Every image needs an `alt` decision.** Meaningful images get alt text conveying purpose; decorative images get `alt=""`.
2. **Describe function, not appearance, for linked or button images** ("Acme home", not "logo").
3. **Don't repeat adjacent text** in alt.
4. **Complex images need a longer description** nearby or linked (charts, diagrams, maps).
5. **Prerecorded video needs captions (1.2.2 A) and audio description or a media alternative (1.2.3 A / 1.2.5 AA). Audio-only needs a transcript (1.2.1 A). Live video needs captions (1.2.4 AA).**
6. **Users control media.** No autoplaying audio over 3 seconds without controls (1.4.2).
7. **Use real text, not images of text** (1.4.5), except logos.

## Best Practices
### Alt text decision tree (after the W3C WAI tree)
| Image is… | alt |
|---|---|
| The only content of a link or button | The destination or action: `alt="Search"`, `alt="Acme home"` |
| Informative (photo conveying info, simple diagram) | Short description of the essential info (usually under ~150 characters) |
| Decorative / purely visual / redundant with adjacent text | `alt=""` (empty, not missing) |
| Text in the image | The same text (and prefer real text) |
| Complex (chart, infographic, map) | Short alt ("Bar chart of 2026 revenue by quarter") plus a long description in page text, `<figcaption>`, `<details>`, or a data table |
| Part of a group conveying one idea (star rating) | One alt on one image ("4 out of 5 stars"), `alt=""` on the rest |
| Avatar next to the user's name | `alt=""` |
| Product photo on a product page | Key visual attributes not in the text (color, style) |

- Don't start with "Image of" or "Picture of". Screen readers already say "image". "Screenshot of" or "Illustration of" is fine when the medium matters.
- Keep file names and CMS captions out of alt. Enforce an alt field in the CMS schema, including an explicit "decorative" checkbox.
- AI-generated alt text (CMS or LLM auto-alt): treat it as a draft that needs human review. Models describe appearance, not purpose or context, and can hallucinate.

### SVG and icons
- Decorative or with a visible label: `aria-hidden="true" focusable="false"`.
- Standalone meaningful inline SVG: `role="img"` plus `aria-label`, or `<title>` referenced via `aria-labelledby`.
- `<img src="icon.svg" alt="…">` is the most robust for static SVG files.
- Icon-only buttons: name the button, not the icon (`<button aria-label="Close">` or a visually hidden span).
- Icon fonts: `aria-hidden="true"` on the glyph element. Users overriding fonts (dyslexia fonts) break icon fonts, so prefer SVG.

### Media
- `<video controls>`, or an accessible player (keyboard-operable, labelled buttons, visible focus, caption toggle, no keyboard traps).
- `<track kind="captions" srclang="en" label="English" default>`. Captions include speaker IDs and meaningful sounds, unlike subtitles.
- Audio description: a separate described version, an AD track (`kind="descriptions"` has poor native support, so a player feature or alternate video is more reliable), or write scripts where visuals are described in the main audio ("integrated description").
- Transcript: full text on the page (collapsible `<details>`), including speakers and visual information. It serves deafblind users and SEO.
- No autoplay with sound. Background videos are muted, `playsInline`, with a pause control, and not autoplayed under reduced motion.
- Animated GIFs over 5 seconds need pause (2.2.2). Use `<video>` with controls instead, or a static image with a play toggle.
- YouTube/Vimeo embeds: set `title` on the `<iframe>` ("Video: Product tour"), enable captions (don't rely on auto-captions without review).

## Implementation Guidance

### next/image
```tsx
import Image from 'next/image';

// Informative
<Image src="/team/ana.jpg" alt="Ana Ruiz presenting the Q3 roadmap on stage" width={800} height={533} />

// Decorative (alt is required by next/image types; pass empty string)
<Image src="/bg-waves.svg" alt="" width={1200} height={400} />

// Linked logo
<Link href="/"><Image src="/logo.svg" alt="Acme home" width={120} height={32} /></Link>
```
`next/image` requires the `alt` prop (it warns or errors without it), but it can't verify quality, so review alt content. eslint-plugin-jsx-a11y `alt-text` also checks `<img>`. Configure `settings['jsx-a11y'].components: { Image: 'img' }` so it checks `next/image` too.

### Inline SVG component
```tsx
type IconProps = React.SVGProps<SVGSVGElement> & { title?: string };
export function Icon({ title, children, ...props }: IconProps) {
  const id = useId();
  return title ? (
    <svg role="img" aria-labelledby={id} {...props}><title id={id}>{title}</title>{children}</svg>
  ) : (
    <svg aria-hidden="true" focusable="false" {...props}>{children}</svg>
  );
}
```

### Complex image with long description
```tsx
<figure aria-labelledby="rev-cap">
  <Image src="/charts/revenue-2026.png" alt="Bar chart: 2026 revenue by quarter, rising each quarter" width={900} height={500} />
  <figcaption id="rev-cap">Revenue grew every quarter in 2026.</figcaption>
  <details>
    <summary>Chart data</summary>
    <table>
      <caption>2026 revenue by quarter (USD millions)</caption>
      <thead><tr><th scope="col">Quarter</th><th scope="col">Revenue</th></tr></thead>
      <tbody><tr><th scope="row">Q1</th><td>4.1</td></tr><tr><th scope="row">Q2</th><td>4.8</td></tr>…</tbody>
    </table>
  </details>
</figure>
```

### Video with captions and transcript
```tsx
<figure>
  <video controls preload="metadata" poster="/tour-poster.jpg" width={1280} height={720}>
    <source src="/tour.mp4" type="video/mp4" />
    <track kind="captions" src="/tour.en.vtt" srcLang="en" label="English" default />
    <track kind="captions" src="/tour.es.vtt" srcLang="es" label="Español" />
  </video>
  <figcaption>Product tour (3 min). <Link href="/tour/audio-described">Audio-described version</Link></figcaption>
  <details>
    <summary>Transcript</summary>
    <p><strong>Narrator:</strong> Welcome to Acme… <em>[Dashboard appears showing three charts]</em></p>
  </details>
</figure>
```
Serve `.vtt` files with `Content-Type: text/vtt`. Cross-origin tracks need CORS plus `crossOrigin` on `<video>`.

## Recommended Workflow
1. Inventory images and media per page or component.
2. Classify each image with the decision tree. Write alt at authoring time, not in QA.
3. Enforce in the CMS schema (required alt or a decorative flag) and in lint (`alt-text`).
4. Media: order captions and transcripts with production. Review auto-captions for accuracy. Plan audio description in the script.
5. Test: screen reader image navigation (NVDA G for graphics; VoiceOver rotor "Images"), captions on and off, keyboard-only player operation, autoplay behaviour.
6. Automate with axe (`image-alt`, `svg-img-alt`, `role-img-alt`, `input-image-alt`, `image-redundant-alt`, `video-caption` (manual check), `frame-title`).

## Patterns
- **CMS alt field with a "decorative" toggle.** Renders `alt=""` explicitly.
- **Caption vs alt.** `<figcaption>` visible to all, alt for what the image conveys. Don't duplicate them.
- **Avatar group.** `alt=""` on images plus visually hidden text "Shared with Ana, Ben, and 3 others".
- **Background image with meaning.** Move it to `<Image>` with alt, or add visually hidden text.
- **Click-to-play embeds (facade).** A lightweight thumbnail button "Play video: Product tour" loads the iframe on activation, then moves focus into the player.

## Anti-Patterns
- **Missing alt attribute.** Screen readers read the file name. Always set alt.
- **`alt="image"`, `alt="photo"`, or the file name.** Meaningless. Describe the purpose.
- **Alt duplicating the adjacent caption or heading.** Double-reading. Use `alt=""` if redundant.
- **Meaningful CSS background images** (hero text baked in, product image) with no text alternative. Use real `<img>` or text.
- **`<svg>` without `aria-hidden` or a name.** Some screen readers announce "group" or read path data. Choose decorative or named.
- **Uncaptioned marketing videos or auto-captions left unreviewed.** 1.2.2 failure when inaccurate.
- **Autoplay with sound.** Interferes with screen reader speech (1.4.2).
- **Custom video players with `div` buttons** lacking names and keyboard support. Use native controls or an accessible player (Media Chrome, Vidstack, Plyr; verify each).

## Accessibility
- 1.1.1 Non-text Content (A), 1.2.1 Audio-only and Video-only (A), 1.2.2 Captions Prerecorded (A), 1.2.3 Audio Description or Media Alternative (A), 1.2.4 Captions Live (AA), 1.2.5 Audio Description Prerecorded (AA), 1.4.2 Audio Control (A), 1.4.5 Images of Text (AA), 2.2.2 Pause Stop Hide (A), 2.1.1 Keyboard (player), 4.1.2 (player controls), 1.4.11 (control icons 3:1).

## Responsive Design
- Art-directed images (`<picture>`, different crops per breakpoint) may need different alt if crops change the content. Keep one alt that fits all crops, or choose crops that convey the same thing.
- Captions must remain legible on small screens. Let users resize them via `::cue` defaults and don't force tiny fonts.
- Text in images doesn't reflow at 400% zoom (1.4.10). Use HTML text overlays.

## Performance
- `next/image` lazy-loads and sizes images, and `alt` doesn't affect performance. Don't use `aria-hidden` to "optimise".
- Facade patterns for video embeds improve LCP. Ensure the facade is a proper button with a name.
- `preload="metadata"` for videos; transcripts are cheap text.

## Security
- Sanitize user-supplied alt text and captions (JSX escapes). Validate `.vtt` uploads (text only).
- Cross-origin caption tracks require correct CORS; don't disable CORS globally to make them work.

## Testing
```tsx
test('decorative and informative images', () => {
  render(<TeamCard />);
  expect(screen.getByRole('img', { name: /ana ruiz presenting/i })).toBeInTheDocument();
  // decorative images have role "presentation" and aren't returned by getByRole('img')
  expect(screen.queryAllByRole('img')).toHaveLength(1);
});
```
- Manual: turn images off (or use the WAVE "no styles" view) to check that the content still makes sense; screen reader graphics navigation; play media with captions; keyboard-only player; review transcript completeness.

## Tooling
- eslint-plugin-jsx-a11y (`alt-text`, `img-redundant-alt`, `media-has-caption`), axe-core, WAVE.
- Next.js `next/image`. CMS schemas (Sanity, Contentful, Payload) with required alt validation.
- Caption tools: platform caption editors (YouTube Studio), Whisper-class ASR plus human review, Amara, 3Play/Rev (commercial).
- Players: native `<video>`, Media Chrome, Vidstack, Able Player (accessibility-focused).

## Framework Notes
- **Next.js.**
  - `next/image` `alt` is required. Map `Image` to `img` in jsx-a11y settings.
  - MDX images: override `img` in `mdx-components.tsx` to require alt.
  - Open Graph images (`opengraph-image.tsx`) also export `alt`.
  - Static video files can be served from `public/` with tracks.
- **React (Vite SPA).** Plain `<img>` with lint enforcement. Import SVGs as components (SVGR) and apply the `Icon` wrapper to control `aria-hidden`/`title`.

## AI Agent Guidance
- Do: decide decorative vs informative for each image; write purpose-based alt; use `alt=""` explicitly for decorative images; hide decorative SVGs; name icon-only buttons.
- Do: add `<track kind="captions">` and transcript placeholders for any video you embed, and flag caption and audio-description content as needing human authoring.
- Don't: invent alt text describing images you can't see with confidence. Ask for it, or mark it TODO for human review.
- Don't: use "image of", file names, autoplay with sound, or div-based player controls.
- Verify before done:
  - no `image-alt`/`svg-img-alt` violations
  - role queries return only meaningful images
  - media has captions and controls

## Examples

### Icon-only button (the icon is decorative; the button carries the name)
```tsx
import { Trash2 } from 'lucide-react';

<button type="button" onClick={onDelete} aria-label="Delete invoice INV-1042">
  <Trash2 aria-hidden="true" focusable="false" />
</button>
```

### CMS-driven image with an explicit decorative flag
```tsx
import Image from 'next/image';

type CmsImage = { url: string; width: number; height: number; alt: string; decorative: boolean };

export function CmsFigure({ image, caption }: { image: CmsImage; caption?: string }) {
  if (!image.decorative && !image.alt.trim()) {
    // Fail loudly in development instead of shipping an unnamed image
    if (process.env.NODE_ENV !== 'production') throw new Error(`Missing alt for ${image.url}`);
  }
  return (
    <figure>
      <Image src={image.url} width={image.width} height={image.height} alt={image.decorative ? '' : image.alt} />
      {caption && <figcaption>{caption}</figcaption>}
    </figure>
  );
}
```

### Accessible video facade (click-to-load embed)
```tsx
'use client';
import { useState } from 'react';

export function VideoFacade({ id, title, poster }: { id: string; title: string; poster: string }) {
  const [loaded, setLoaded] = useState(false);
  if (loaded) {
    return (
      <iframe ref={(el) => el?.focus()} title={`Video: ${title}`} allow="autoplay; fullscreen"
        src={`https://www.youtube-nocookie.com/embed/${id}?autoplay=1&cc_load_policy=1`} className="aspect-video w-full" />
    );
  }
  return (
    <button type="button" onClick={() => setLoaded(true)} className="relative aspect-video w-full">
      <img src={poster} alt="" className="h-full w-full object-cover" />
      <span className="sr-only">Play video: {title}</span>
    </button>
  );
}
```

## Related Skills
- [image-optimization](../image-optimization/Skill.md) — performance side of images
- [nextjs-image-and-font-optimization](../nextjs-image-and-font-optimization/Skill.md) — next/image configuration
- [responsive-images-and-media](../responsive-images-and-media/Skill.md) — picture/srcset
- [accessible-data-visualization](../accessible-data-visualization/Skill.md) — charts beyond alt text
- [iconography-and-illustration](../iconography-and-illustration/Skill.md) — icon systems
- [reduced-motion-and-vestibular-safety](../reduced-motion-and-vestibular-safety/Skill.md) — autoplay and GIFs
- [semantic-html](../semantic-html/Skill.md) — figure/figcaption

## Sources
- [W3C WAI Images Tutorial & alt Decision Tree](https://www.w3.org/WAI/tutorials/images/decision-tree/) — Official — alt decisions
- [W3C WAI Making Audio and Video Media Accessible](https://www.w3.org/WAI/media/av/) — Official — captions, transcripts, description
- [Understanding 1.2.2 / 1.2.5 / 1.4.2 / 1.4.5](https://www.w3.org/WAI/WCAG22/Understanding/) — Official — requirements
- [WebAIM Million 2026](https://webaim.org/projects/million/) — Community research — 53.1% missing alt
- [Next.js Image component docs](https://nextjs.org/docs/app/api-reference/components/image) — Official — required alt
- [eslint-plugin-jsx-a11y](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y) — Open Source — alt-text, media-has-caption
- [Sara Soueidan / Léonie Watson on accessible SVG](https://www.sarasoueidan.com/) — Community — SVG naming patterns

## License / Usage Notes
Summarised from W3C tutorials and docs. Code examples are original.

## Quality Tier
S — official decision tree and media guidance, with Next.js-specific enforcement.

## Status
Active

## Last Verified
2026-09-15
