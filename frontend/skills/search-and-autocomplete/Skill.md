# Search and Autocomplete

## Summary
How to build search inputs with live suggestions: site and app search boxes, query suggestions, recent searches, instant results, and address or entity lookup where free text is allowed. Covers `<search>`/`type="search"` semantics, the APG editable combobox with `aria-autocomplete`, debounce and abort, result announcements, suggestion content design (NN/g, Baymard), and libraries (Algolia Autocomplete, Base UI Autocomplete, React Aria Autocomplete, Downshift). Picking a value from a closed list is covered by `select-and-combobox`.

## Category
Components

## Subcategories
Site search, typeahead, query suggestions, instant search, recent searches, debounce/abort, combobox (editable), search landmark

## Problem It Solves
Search is a primary way users find things, and poor autocomplete hurts it directly. Common failures: irrelevant or zero-result suggestions, flicker from out-of-order responses, requests fired on every keystroke, suggestions that hijack the Enter key, dropdowns screen readers never announce, and mobile keyboards covering results. This skill gives a correct, fast, accessible baseline.

## When To Use
- A global or section search box with query suggestions or instant results.
- Free-text fields that benefit from suggestions but accept any input: address lookup, city, job title, product name.
- Searching within a large dataset where results preview in a dropdown before a full results page.
- Recent and popular searches shown on focus.

## When Not To Use
- The value must be one of a fixed set: use `select-and-combobox`.
- Command execution or app-wide navigation with shortcuts: use `command-palette`.
- Filtering an already displayed list or table by facets: use `filters-and-faceted-search`.
- Tiny lists (under ~10 items) where a plain filter input over visible items works better.
- Mentions or inline completions inside rich text: see `rich-text-editors`.

## Core Principles
1. **The user's query wins.** Enter with no highlighted suggestion submits exactly what was typed. Suggestions never replace the query unless the user picks one. APG's "list" autocomplete keeps DOM focus in the input.
2. **Every suggestion must return good results** (NN/g). A suggestion that leads to zero or irrelevant results is worse than none.
3. **Show the difference between typed text and suggested text.** When completing, bold the completion. When matching mid-string, highlight the user's query.
4. **Fast and ordered.** Show local or recent results right away, debounce the network, abort stale requests, and never let an older response overwrite a newer one.
5. **Simple text suggestions stay the core.** Rich suggestions (products, categories, images) are an optional extra and must be labeled. Keep mobile to simple text.
6. **Announce, don't narrate.** Tell AT how many suggestions are available, politely and after typing settles.

## Best Practices
- Wrap the search UI in `<search>` (implicit `search` landmark, Baseline since 2023). Use `<input type="search">` with a visible label, which can be visually hidden only if a magnifier button and clear context exist. Include a submit button.
- Set `enterkeyhint="search"`, `autocomplete="off"` for custom suggestions (keep browser autofill for address fields: `autocomplete="street-address"` etc.), `spellcheck="false"` for code or SKU searches.
- Minimum query length: 0 for recent/popular on focus, 1–2 characters for remote queries. Short queries on huge indexes are expensive and noisy.
- Debounce remote calls by 150–300 ms. Throttle instead of debounce if you want results to appear while the user types continuously.
- Cap suggestions at about 6–10 on desktop and 4–6 on mobile. Group by type ("Suggestions", "Products", "Categories") with visible group labels.
- Scoped suggestions ("in Men's Shoes") are labeled and styled differently. The default top suggestion is unscoped (NN/g).
- Recent searches: show on focus with an empty query, let users remove individual items, store locally, and never sync without consent.
- Tolerate typos (fuzzy match or a "Did you mean" row) and normalize diacritics and case.
- Keep the dropdown open while typing. Close it on Escape, on blur (after click handling), and after submit.
- Show a clear (×) button once there is text. Escape clears on a second press, the common `type="search"` behavior.
- Always offer a "See all results for 'query'" row that leads to the full results page.
- Preserve the query in the URL (`?q=`) on the results page so it can be shared, bookmarked, and survive back/forward.

## Implementation Guidance

### Anatomy
```
<search>
  <form role=none action="/search">
    label ("Search products")
    input[type=search][role=combobox][aria-expanded][aria-controls][aria-autocomplete=list][aria-activedescendant]
    clear button (type=button, aria-label="Clear search")
    submit button (aria-label="Search")
    popup [role=listbox] (or grouped listbox)
      group label  → option(s) with highlighted match
      "See all results for “q”" option
    status [role=status aria-live=polite] (visually hidden: "8 suggestions")
```

### Keyboard
| Key | Behavior |
|---|---|
| Typing | Updates query; popup opens with suggestions (after min length) |
| Down / Up | Moves highlight through suggestions (wraps optional); input text may preview highlighted suggestion (`aria-autocomplete="both"` style) but restore on Escape |
| Enter | If a suggestion is highlighted → navigate/select it; else submit typed query |
| Escape | Close popup (restore typed text if previewing); second Escape clears input |
| Tab | Close popup, move focus normally (don't auto-commit a suggestion in free-text search) |
| Alt+Down | Open popup without moving highlight |
| Delete on recent search item | (Optional) remove item; also provide a visible remove button |

### Choosing the popup pattern
| Suggestion content | Popup role |
|---|---|
| Text-only suggestions, maybe grouped | `listbox` with `group`s |
| Rows with secondary actions (e.g., "remove" recent search, "fill query" arrow) | `grid` popup (`aria-haspopup="grid"`) or place actions outside |
| Complex panel (tabs, filters, previews) | Non-modal `dialog` popup; real focus moves in |

### Request lifecycle
1. Hold `query` state and update it immediately (a controlled input must never lag).
2. Derive `debouncedQuery` (useDeferredValue alone does not reduce network calls, so use a real debounce).
3. Fetch with an `AbortController`. Include the query in the cache key (TanStack Query `queryKey: ['suggest', q]` with `signal` passed to fetch, `placeholderData: keepPreviousData`).
4. Render in this priority: previous results dimmed plus a subtle spinner → new results → "No suggestions" + "Search for 'q'" row → error row.
5. Update the live region with the count after results render. Throttle announcements to at most one per settle.

## Recommended Workflow
1. Define the scope: what is searched, whether it is free text or a closed set, and whether there is a full results page.
2. Agree on suggestion content with product and search owners: query completions, recent, popular, entities. Set limits per group.
3. Build the backend contract: a `/suggest?q=` endpoint that is fast (under 100 ms at p50), cacheable, and rate-limited.
4. Pick a primitive (Base UI `Autocomplete`, React Aria `Autocomplete`/`ComboBox allowsCustomValue`, Downshift `useCombobox`, or Algolia Autocomplete).
5. Implement the input, popup, and states (idle, typing, loading, results, empty, error, offline).
6. Add URL sync on the results page and analytics (query, suggestion position clicked, zero-result queries).
7. Test keyboard, NVDA/JAWS/VoiceOver announcements, slow network (throttle to 3G), and a mobile viewport with the on-screen keyboard.
8. Review zero-result and abandoned queries after launch to tune suggestions.

## Patterns
- **Query suggestions + instant results.** Left column shows query completions, right column (desktop only) shows the top 3 product or entity hits. Mobile shows completions only.
- **Recent searches on focus.** An empty query shows the last 5 searches, each with a remove button, plus "Clear all".
- **Address lookup.** Free text with provider suggestions (Places or postcode API). Selecting one fills structured fields, which stay editable. Always allow manual entry.
- **Search-as-filter.** An input filtering a visible list in place. Not a combobox: use a plain `type="search"` input and a live region with the result count.
- **Inline completion (`aria-autocomplete="both"`).** Typeahead text appears selected after the caret. Use sparingly, only when there is a single highly likely completion (e.g., email domain).
- **Full-screen mobile search.** Tapping the header search opens an overlay with a focused input, back button, recent searches, and suggestions.

```tsx
// app/components/use-suggestions.ts — debounced, aborting suggestion hook with TanStack Query
'use client';
import {useQuery, keepPreviousData} from '@tanstack/react-query';
import {useEffect, useState} from 'react';

export type Suggestion = {id: string; text: string; type: 'query' | 'product'; href: string};

function useDebounced<T>(value: T, ms = 200) {
  const [v, setV] = useState(value);
  useEffect(() => { const t = setTimeout(() => setV(value), ms); return () => clearTimeout(t); }, [value, ms]);
  return v;
}

export function useSuggestions(query: string) {
  const q = useDebounced(query.trim());
  return useQuery({
    queryKey: ['suggest', q],
    enabled: q.length >= 2,
    placeholderData: keepPreviousData,
    staleTime: 60_000,
    queryFn: async ({signal}) => {
      const r = await fetch(`/api/suggest?q=${encodeURIComponent(q)}`, {signal}); // aborts when key changes
      if (!r.ok) throw new Error('Suggest failed');
      return (await r.json()) as Suggestion[];
    },
  });
}
```

## Anti-Patterns
| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Auto-highlighting the first suggestion in free-text search | Enter submits the suggestion instead of what was typed | No auto-highlight (`autoHighlight={false}`), or only highlight on an exact prefix match |
| Fetch on every keystroke with no abort | Server load, flicker, stale results overwrite fresh ones | Debounce + AbortController / query-keyed cache |
| Suggestions that return zero results | Sends users down dead ends | Generate suggestions from successful queries and the index itself |
| Moving focus into the list | Typing stops working and the caret is lost | `aria-activedescendant`, focus stays in the input |
| Silent popup (no live status) | Screen reader users don't know suggestions exist | Polite status "N suggestions available" |
| Placeholder as the only label | Disappears on typing, low contrast | Visible or visually hidden `<label>` |
| `innerHTML` for bold match highlighting | XSS from indexed content | Split strings, render `<mark>` elements |
| Rich product cards in mobile dropdown | Slow, cramped, hidden by keyboard | Text-only on mobile. Rich previews on the results page |
| Disabling browser autofill on address fields | Slows entry for everyone | Keep `autocomplete` tokens and layer suggestions on top |
| Closing popup on `blur` before click registers | Clicks on suggestions are lost | Use `pointerdown` + `preventDefault` on options, or library handling |
| Query not in URL | Can't share, back button loses search | Sync `q` to URL on the results page |

## Accessibility
- Use a landmark: `<search>` (or `role="search"` on a form in legacy code). Only one or two per page, labeled if more than one.
- Combobox semantics per APG: `role="combobox"`, `aria-expanded`, `aria-controls`, `aria-autocomplete="list"` (or `both`), `aria-activedescendant` for the highlighted option.
- WCAG 4.1.3 Status Messages: announce the suggestion count and "no results" with `role="status"`. GOV.UK accessible-autocomplete delays announcements to avoid talking over typing, which is a good model.
- WCAG 3.2.2 On Input: typing must not navigate away or submit automatically. Instant results are fine, but navigation requires Enter or a click.
- WCAG 1.4.3/1.4.11: match highlighting must not rely on color alone (use bold or `<mark>`), and the highlighted row needs a ≥3:1 indicator.
- WCAG 2.5.8: clear and remove buttons ≥24×24 px.
- Grouped suggestions: group labels must be exposed (`role="group"` + `aria-labelledby`), not just visual headings.
- Give the clear button a label ("Clear search") and return focus to the input after clearing.

## Responsive Design
- Mobile: expand to a full-screen search overlay. Pin the input to the top so the on-screen keyboard doesn't cover suggestions. Size the list with the VisualViewport or `dvh`.
- Keep suggestion rows ≥44 px tall. Use a large tap area for "fill query" arrows (the Google-style ↖ that copies a suggestion into the input without submitting).
- Desktop: the popup may be wider than the input for two-column layouts. Constrain it to the viewport and flip above if needed.
- `enterkeyhint="search"` shows a Search key. `inputmode="search"` is rarely needed because `type="search"` covers it.

## Performance
- Target under 100 ms server p50 for suggest endpoints. Use CDN or edge caching for popular prefixes.
- Prefetch recent or popular searches on focus, or on idle for the header search.
- Use `placeholderData: keepPreviousData` (or equivalent) to avoid layout jumps. Reserve popup min-height to avoid CLS in inline results.
- Keep the input update synchronous and push result rendering to a transition (`startTransition`/`useDeferredValue`) to protect INP.
- Code-split heavy search SDKs (InstantSearch, Autocomplete.js) and load them on first focus or intent.

## Security
- Treat suggestion text as untrusted and escape it. Match highlighting must not use HTML injection.
- Rate-limit suggest endpoints and require auth for private data. Enforce tenant scoping server-side so suggestions don't leak other users' records or queries.
- Use search-only API keys client-side (e.g., Algolia search-only or secured API keys with filters). Never ship admin keys.
- Recent searches may be sensitive (health, legal). Store locally, offer clear controls, and exclude them from analytics or telemetry where required.
- Don't reflect raw `q` into the page title or HTML without escaping.

## Testing
- Component: type → debounced fetch called once. Rapid typing → only the last request resolves into the UI (MSW with delayed handlers). Enter without highlight submits the typed text. Down+Enter picks a suggestion. Escape restores and then clears.
- Accessibility: roles and attributes (`aria-expanded`, `aria-activedescendant` changes on Arrow), status text updates, axe scan with the popup open.
- E2E (Playwright): slow network emulation, mobile overlay flow, URL contains `q` and back/forward restores.
- Analytics assertions: suggestion position and zero-result events fire.
- Manual: NVDA + Firefox/Chrome, VoiceOver iOS Safari (announcements are fragile).

## Tooling
| Tool | Notes (Sept 2026) |
|---|---|
| Base UI `Autocomplete` | Free-text input with `mode` (`list`/`both`/`inline`/`none`), `limit`, `autoHighlight`, `openOnInputClick`, `submitOnItemClick`; use `Combobox` instead when the value must be from the list |
| React Aria `Autocomplete` | Wraps `SearchField`/`TextField` with `Menu`/`ListBox`/`GridList`; virtual focus by default, `filter` + `useFilter`, `disableAutoFocusFirst`; server filtering via `useAsyncList` |
| Downshift `useCombobox` | Headless ARIA 1.2 hooks; full rendering control |
| Algolia Autocomplete (`@algolia/autocomplete-js`) | Open-source, backend-agnostic; `getSources`, plugins for recent searches and query suggestions |
| React InstantSearch v7 (`react-instantsearch`) | Search results page widgets (`SearchBox`, `Hits`, refinements) |
| GOV.UK `accessible-autocomplete` | Vanilla, good live-region behavior, `minLength`, `confirmOnBlur`, `tNoResults` |
| TanStack Query | Query-keyed caching, abort via `signal`, `keepPreviousData` |
| Search backends: Algolia, Meilisearch, Typesense, Elasticsearch/OpenSearch | Prefix/typo-tolerant suggest indexes |

## Framework Notes
- **Next.js App Router**:
  - The results page is a Server Component. It awaits `searchParams` (a Promise in Next 15+), validates `q`, and streams results (see `nextjs-streaming-and-loading-ui`).
  - Render the search box inside `next/form`'s `<Form action="/search">`. It is a GET form that works before hydration and does a client-side navigation after it.
  - The suggestion combobox is a Client Component, fed by a cacheable GET Route Handler (`app/api/suggest/route.ts`). Don't use Server Actions for suggestions: they are POST, run one at a time, and are not cacheable.
  - For search-as-you-type on the results page, use nuqs `useQueryState('q')` (`shallow: false` to re-run the server page) or `useSearchParams` + `router.replace`. Use `push` on explicit submit. Wrap components that read `useSearchParams` in `<Suspense>`.
- **React (Vite SPA)**:
  - Put the query in the URL with nuqs (React or React Router adapter) or React Router's `useSearchParams`.
  - Fetch results and suggestions with TanStack Query keyed on `q`.
  - Keep a real `<form method="get">` so Enter and the submit button work natively.
  - `useDeferredValue` keeps rendering responsive but does not reduce requests. Debounce the network separately.

## AI Agent Guidance
- Do: decide free-text (Autocomplete) vs closed set (Combobox) before coding and state it.
- Do: implement debounce, abort (TanStack Query `signal` or `AbortController`), minimum length, loading/empty/error rows, and a polite status message.
- Do: in Next.js, use a GET `next/form` (works without JS), a Server Component results page reading `searchParams`, and a Route Handler for suggestions. Never use a Server Action to fetch suggestions.
- Do: keep Enter submitting the typed query when nothing is highlighted, and add "See all results for 'q'".
- Do: wrap in `<search>`, label the input, and sync `q` to the URL on results pages.
- Don't: auto-highlight the first suggestion in free-text search, render highlights via `innerHTML`, or embed private API keys.
- Verify before done: a network log shows one request per settled query and cancelled stale requests; keyboard flow works; a screen reader announces the count; mobile overlay is not covered by the keyboard; back button restores the search.

## Examples

```tsx
// app/components/site-search.tsx — Server Component shell. next/form renders a GET form:
// before hydration (or without JS) it submits ?q=…; after hydration it navigates client-side.
import Form from 'next/form';
import {SearchBox} from './search-box';

export function SiteSearch({defaultQuery = ''}: {defaultQuery?: string}) {
  return (
    // If your @types/react predates <search>, use <div role="search">
    <search>
      <Form action="/search">
        <SearchBox defaultQuery={defaultQuery} />
        <button type="submit" aria-label="Search">🔍</button>
      </Form>
    </search>
  );
}
```

```tsx
// app/components/search-box.tsx — Downshift useCombobox enhancement (SSR outputs a working <input name="q">)
'use client';
import {useCombobox} from 'downshift';
import {useRouter} from 'next/navigation';
import {useState} from 'react';
import {useSuggestions, type Suggestion} from './use-suggestions';

function Highlight({text, query}: {text: string; query: string}) {
  const i = text.toLowerCase().indexOf(query.trim().toLowerCase());
  if (!query.trim() || i < 0) return <>{text}</>;
  const end = i + query.trim().length;
  return <>{text.slice(0, i)}<mark>{text.slice(i, end)}</mark>{text.slice(end)}</>;
}

export function SearchBox({defaultQuery}: {defaultQuery: string}) {
  const router = useRouter();
  const [query, setQuery] = useState(defaultQuery);
  const {data: items = [], isFetching, isError} = useSuggestions(query);
  const eligible = query.trim().length >= 2;

  const {isOpen, highlightedIndex, getLabelProps, getInputProps, getMenuProps, getItemProps} = useCombobox<Suggestion>({
    items,
    inputValue: query,
    itemToString: (item) => item?.text ?? '',
    onInputValueChange: ({inputValue}) => setQuery(inputValue ?? ''),
    onSelectedItemChange: ({selectedItem}) => { if (selectedItem) router.push(selectedItem.href); },
    // No default highlight: Enter with nothing highlighted is not intercepted, so the native form submits the typed query.
  });

  const open = isOpen && eligible;
  const status = !open || isFetching ? '' : isError ? 'Suggestions unavailable' : `${items.length} suggestions available`;

  return (
    <>
      <label {...getLabelProps()} className="sr-only">Search products</label>
      <input {...getInputProps({name: 'q', type: 'search', enterKeyHint: 'search', autoComplete: 'off', spellCheck: false})} />
      <ul {...getMenuProps()} hidden={!open || items.length === 0} className="suggestions">
        {open && items.map((item, index) => (
          <li key={item.id} {...getItemProps({item, index})} data-highlighted={highlightedIndex === index || undefined}>
            <Highlight text={item.text} query={query} />
          </li>
        ))}
      </ul>
      {open && !isFetching && !isError && items.length === 0 && <p className="suggestions-empty">No suggestions. Press Enter to search for “{query}”.</p>}
      <p role="status" className="sr-only">{status}</p>
    </>
  );
}
```

```tsx
// app/api/suggest/route.ts — cacheable GET endpoint (not a Server Action)
import {NextResponse, type NextRequest} from 'next/server';
import {suggest} from '@/lib/search'; // server-only; applies tenant/auth scoping

export async function GET(req: NextRequest) {
  const q = (req.nextUrl.searchParams.get('q') ?? '').trim().slice(0, 100);
  if (q.length < 2) return NextResponse.json([]);
  const items = await suggest(q);
  // Public CDN caching only for non-personalized suggestions; otherwise use `private, max-age=30`
  return NextResponse.json(items, {headers: {'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300'}});
}
```

```tsx
// app/search/page.tsx — Server Component results page driven by the URL
import Link from 'next/link';
import {Suspense} from 'react';
import {SiteSearch} from '@/app/components/site-search';
import {searchProducts} from '@/lib/search';

async function Results({q}: {q: string}) {
  const hits = await searchProducts(q);
  if (!hits.length) return <p role="status">No results for “{q}”. Check the spelling or try a broader term.</p>;
  return (
    <>
      <p role="status">{hits.length} results</p>
      <ul>{hits.map((h) => <li key={h.id}><Link href={h.href}>{h.title}</Link></li>)}</ul>
    </>
  );
}

export default async function SearchPage({searchParams}: {searchParams: Promise<{q?: string | string[]}>}) {
  const {q: raw} = await searchParams;
  const q = (Array.isArray(raw) ? raw[0] : raw ?? '').trim().slice(0, 200);
  return (
    <>
      <SiteSearch key={q} defaultQuery={q} />
      <main>
        <h1>{q ? `Results for “${q}”` : 'Search'}</h1>
        <Suspense key={q} fallback={<p aria-busy="true">Searching…</p>}>
          {q ? <Results q={q} /> : <p>Enter a search term.</p>}
        </Suspense>
      </main>
    </>
  );
}
```

```tsx
// Search-as-filter over a visible list, URL-synced with nuqs (not a combobox).
// Without JS the GET form submits ?q=…, so the parent Server Component should also filter by searchParams.q.
'use client';
import {useQueryState, parseAsString} from 'nuqs';
import {useDeferredValue} from 'react';

export function FilterableList({items}: {items: {id: string; title: string}[]}) {
  const [q, setQ] = useQueryState('q', parseAsString.withDefault('').withOptions({history: 'replace'}));
  const needle = useDeferredValue(q).trim().toLowerCase();
  const visible = needle ? items.filter((i) => i.title.toLowerCase().includes(needle)) : items;
  return (
    <>
      <search>
        <form method="get" onSubmit={(e) => e.preventDefault()}>
          <label htmlFor="list-q">Filter articles</label>
          <input id="list-q" name="q" type="search" value={q} onChange={(e) => setQ(e.target.value || null)} />
        </form>
      </search>
      <p role="status">{visible.length} of {items.length} articles</p>
      <ul>{visible.map((i) => <li key={i.id}>{i.title}</li>)}</ul>
    </>
  );
}
```
Downshift's hooks no longer produce default a11y status messages, which is why the example renders its own `role="status"`. Check the nuqs version you have for URL update rate-limiting options (throttle or debounce) before relying on them.

## Related Skills
- [select-and-combobox](../select-and-combobox/Skill.md) — closed-set selection with the same ARIA foundation
- [filters-and-faceted-search](../filters-and-faceted-search/Skill.md) — refining the results page
- [tags-and-chips-input](../tags-and-chips-input/Skill.md) — search that produces multiple tokens
- [command-palette](../command-palette/Skill.md) — app command search
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — input anatomy, `enterkeyhint`, autocomplete tokens
- [react-data-fetching-tanstack-query](../react-data-fetching-tanstack-query/Skill.md) — caching and abort
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — status messages
- [ecommerce-ux-patterns](../ecommerce-ux-patterns/Skill.md) — product search context
- [empty-states](../empty-states/Skill.md) — zero-results design
- [inp-optimization](../inp-optimization/Skill.md) — keeping typing responsive
- [landmarks-and-accessible-navigation](../landmarks-and-accessible-navigation/Skill.md) — search landmark
- [react-url-state-nuqs](../react-url-state-nuqs/Skill.md) — query in the URL
- [progressive-enhancement](../progressive-enhancement/Skill.md) — GET form fallback
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — cacheable suggest endpoint
- [nextjs-streaming-and-loading-ui](../nextjs-streaming-and-loading-ui/Skill.md) — streaming results page

## Sources
- [WAI-ARIA APG: Combobox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/) — Official — `aria-autocomplete` modes, focus model, keyboard
- [MDN: `<search>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/search) — Official — landmark semantics, Baseline status
- [NN/g: Site Search Suggestions](https://www.nngroup.com/articles/site-search-suggestions/) — Community (research) — relevance, highlighting, scope, mobile simplification
- [NN/g: Enriched Site-Search Suggestions](https://www.nngroup.com/articles/enriched-site-search-suggestions/) — Community (research) — keep text suggestions, label rich types
- [Base UI Autocomplete](https://base-ui.com/react/components/autocomplete) — Open Source — `mode`, `limit`, Autocomplete vs Combobox guidance
- [React Aria Autocomplete](https://react-aria.adobe.com/Autocomplete) — Open Source — virtual focus, filter, use cases
- [Algolia Autocomplete](https://www.algolia.com/doc/ui-libraries/autocomplete/introduction/what-is-autocomplete/) — Open Source — sources/plugins model
- [alphagov/accessible-autocomplete](https://github.com/alphagov/accessible-autocomplete) — Open Source — polite delayed status, `minLength`, `confirmOnBlur`
- [Downshift](https://github.com/downshift-js/downshift) — Open Source — headless combobox hooks

## License / Usage Notes
Summarized from W3C (W3C Document License), MDN (CC-BY-SA), NN/g articles (copyrighted, paraphrased only), and MIT/Apache-licensed library docs. Algolia Autocomplete is MIT, but Algolia's hosted search is a commercial service. Code is original and illustrative.

## Quality Tier
A — Standards plus usability research plus current library APIs. Algolia plugin specifics and iOS VoiceOver behavior were not re-verified hands-on.

## Status
Active

## Last Verified
2026-09-15
