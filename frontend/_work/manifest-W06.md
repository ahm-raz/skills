# Manifest — W06 Components: Overlays, Navigation, Display

Scope: React + Next.js (TypeScript) per TAXONOMY scope note. Last verified 2026-09-15.
Skills written: 19 (18 assigned + 1 added: `resizable-panels`). Skipped: none.

## Skills

| Slug | Title | Category | Framework | Quality | Status | Primary Source (URL) |
|---|---|---|---|---|---|---|
| accessible-dialogs | Accessible Dialogs | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/ |
| drawers-and-sheets | Drawers and Sheets | Components | React, Next.js | A | Active | https://www.nngroup.com/articles/bottom-sheet/ |
| dropdown-menus | Dropdown Menus | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/menubar/ |
| tooltips | Tooltips | Components | React, Next.js | A | Active | https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html |
| popovers | Popovers | Components | React, Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using |
| tabs | Tabs | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/tabs/ |
| accordions-and-disclosure | Accordions and Disclosure | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/accordion/ |
| cards | Cards | Components | React, Next.js | B | Active | https://inclusive-components.design/cards/ |
| command-palette | Command Palette | Components | React, Next.js | B | Active | https://github.com/dip/cmdk |
| pagination | Pagination | Components | React, Next.js | A | Active | https://design-system.service.gov.uk/components/pagination/ |
| navigation-menus-and-sidebars | Navigation Menus and Sidebars | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/ |
| breadcrumbs | Breadcrumbs | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/ |
| toasts-and-notifications | Toasts and Notifications | Components | React, Next.js | A | Active | https://react-aria.adobe.com/Toast |
| carousels | Carousels | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/carousel/ |
| tree-views | Tree Views | Components | React, Next.js | A | Active | https://www.w3.org/WAI/ARIA/apg/patterns/treeview/ |
| drag-and-drop | Drag and Drop | Components | React, Next.js | A | Active | https://atlassian.design/components/pragmatic-drag-and-drop/accessibility-guidelines |
| floating-element-positioning | Floating Element Positioning | Components | React, Next.js | A | Active | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Anchor_positioning/Using |
| list-virtualization | List Virtualization | Components | React, Next.js | A | Active | https://tanstack.com/virtual/latest/docs/api/virtualizer |
| resizable-panels (added) | Resizable Panels | Components | React, Next.js | B | Active | https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/ |

## Sources

| Source | URL | Type | What Was Extracted | Why It Matters | Quality | Last Verified |
|---|---|---|---|---|---|---|
| WAI-ARIA APG Patterns index | https://www.w3.org/WAI/ARIA/apg/patterns/ | Official | Pattern inventory (incl. window splitter, feed) | Canonical widget semantics | S | 2026-09-15 |
| APG Dialog (Modal) | https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/ | Official | Keyboard, roles, initial focus, focus return | Dialog/drawer baseline | S | 2026-09-15 |
| APG Menu Button / Menu and Menubar | https://www.w3.org/WAI/ARIA/apg/patterns/menubar/ | Official | Full menu keyboard model, roving vs activedescendant | Dropdown/context menus | S | 2026-09-15 |
| APG Tabs | https://www.w3.org/WAI/ARIA/apg/patterns/tabs/ | Official | Activation modes, panel tabindex | Tabs | S | 2026-09-15 |
| APG Tree View | https://www.w3.org/WAI/ARIA/apg/patterns/treeview/ | Official | Keys, multi-select models, level/setsize | Tree views | S | 2026-09-15 |
| APG Carousel | https://www.w3.org/WAI/ARIA/apg/patterns/carousel/ | Official | Rotation control, roledescription, aria-live | Carousels | S | 2026-09-15 |
| APG Tooltip | https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/ | Official | Role, Escape, WIP status | Tooltips | A | 2026-09-15 |
| APG Accordion | https://www.w3.org/WAI/ARIA/apg/patterns/accordion/ | Official | Heading/button, region guidance | Accordions | S | 2026-09-15 |
| APG Breadcrumb | https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/ | Official | nav label, aria-current | Breadcrumbs | S | 2026-09-15 |
| APG Disclosure Navigation example | https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/ | Official | Why not menu role for nav, Escape | Navigation menus | S | 2026-09-15 |
| APG Window Splitter | https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/ | Official | Separator role/value, keys | Resizable panels | S | 2026-09-15 |
| APG Feed | https://www.w3.org/WAI/ARIA/apg/patterns/feed/ | Official | feed/article, aria-busy, keys | Infinite lists | S | 2026-09-15 |
| APG Alert | https://www.w3.org/WAI/ARIA/apg/patterns/alert/ | Official | No focus change, avoid auto-dismiss | Toasts | S | 2026-09-15 |
| WCAG 2.2 Understanding 1.4.13 | https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html | Official | Dismissible/hoverable/persistent | Tooltips/popovers | S | 2026-09-15 |
| MDN `<dialog>` | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog | Official | showModal, closedby, requestClose, animation | Dialogs | S | 2026-09-15 |
| MDN Popover API | https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using | Official | auto/manual/hint, stacks, implicit anchor, a11y | Popovers/tooltips/menus | S | 2026-09-15 |
| MDN Anchor positioning guide | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Anchor_positioning/Using | Official | position-area, fallbacks, anchor-scope | Positioning | S | 2026-09-15 |
| MDN inert | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert | Official | Behavior, Baseline widely available | Dialogs/carousels | S | 2026-09-15 |
| MDN ::scroll-marker | https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/::scroll-marker | Official | Experimental status, generated tablist semantics | Carousels | A | 2026-09-15 |
| web-features: dialog closedby | https://web-platform-dx.github.io/web-features-explorer/features/dialog-closedby/ | Official | Chrome 134, Firefox 141, no Safari | Dialog support matrix | A | 2026-09-15 |
| web-features: interest invokers | https://web-platform-dx.github.io/web-features-explorer/features/interest-invokers/ | Official | Chromium 142+ only | Tooltips | A | 2026-09-15 |
| caniuse: anchor positioning | https://caniuse.com/css-anchor-positioning | Community | Full vs partial support per engine | Positioning (conflicting data noted) | B | 2026-09-15 |
| InfoQ: Invoker Commands Baseline | https://www.infoq.com/news/2026/01/html-invoker-commands/ | Community | Chrome 135/Firefox 144/Safari 26.2 | Declarative dialogs/popovers | B | 2026-09-15 |
| Chrome for Developers: popover=hint | https://developer.chrome.com/blog/popover-hint | Official | hint semantics | Tooltips | A | 2026-09-15 |
| Chrome for Developers: Carousels with CSS | https://developer.chrome.com/blog/carousels-with-css | Official | scroll-button/marker, Chrome 135 | Carousels | A | 2026-09-15 |
| Chrome for Developers: Exclusive accordion | https://developer.chrome.com/docs/css-ui/exclusive-accordion | Official | details name | Accordions | A | 2026-09-15 |
| GOV.UK Design System (pagination, tabs, accordion, breadcrumbs) | https://design-system.service.gov.uk/components/ | Official | When to use/not use, markup, mobile, research | Design guidance | S | 2026-09-15 |
| NN/g articles (tooltips, tabs, carousels, breadcrumbs, bottom sheets, notifications) | https://www.nngroup.com/articles/ | Official (research) | Usability rules | UX guidance | A | 2026-09-15 |
| Inclusive Components: Cards | https://inclusive-components.design/cards/ | Community (expert) | Clickable card techniques | Cards | A | 2026-09-15 |
| Atlassian Pragmatic DnD a11y guidelines | https://atlassian.design/components/pragmatic-drag-and-drop/accessibility-guidelines | Official (design system) | Action menus, announcements, focus | Drag and drop | S | 2026-09-15 |
| Pragmatic drag and drop repo | https://github.com/atlassian/pragmatic-drag-and-drop | Open Source | Packages, APIs, size | Drag and drop | A | 2026-09-15 |
| dnd kit docs / @dnd-kit/react | https://dndkit.com/ | Open Source | New architecture, 0.5.0 pre-1.0 | Drag and drop | B | 2026-09-15 |
| React Aria DnD / Tree / Toast | https://react-aria.adobe.com/ | Open Source | Keyboard DnD, Tree anatomy, toast timing/F6 | Several skills | A | 2026-09-15 |
| Floating UI docs (useFloating, useHover) | https://floating-ui.com/docs/useFloating | Open Source | Middleware, autoUpdate, safePolygon | Positioning/tooltips/menus | A | 2026-09-15 |
| TanStack Virtual API + 2026 blog posts | https://tanstack.com/virtual/latest/docs/api/virtualizer | Open Source | Options, chat anchoring, snapshots | List virtualization | A | 2026-09-15 |
| Embla Carousel accessibility plugin / v9 notes | https://www.embla-carousel.com/docs/plugins/accessibility | Open Source | v9 RC a11y plugin options | Carousels | B | 2026-09-15 |
| Base UI releases | https://base-ui.com/react/overview/releases | Open Source | v1.8.0 (Sept 2026), Drawer stable v1.3 | Library status | A | 2026-09-15 |
| Radix NavigationMenu / Tooltip | https://www.radix-ui.com/primitives/docs/components/navigation-menu | Open Source | Disclosure model; tooltip delays 700/300 | Nav/tooltips | A | 2026-09-15 |
| shadcn/ui Sidebar | https://ui.shadcn.com/docs/components/sidebar | Open Source | Provider, collapsible modes, ⌘B, mobile sheet | Sidebars | A | 2026-09-15 |
| cmdk README | https://github.com/dip/cmdk | Open Source | API parts, filtering, pages | Command palette | A | 2026-09-15 |
| Sonner docs | https://sonner.emilkowal.ski/toast | Open Source | Types, promise, default 4000ms | Toasts | B | 2026-09-15 |
| Vaul repository | https://github.com/emilkowalski/vaul | Archived (unmaintained notice) | Unmaintained status | Drawers migration warning | B | 2026-09-15 |
| react-resizable-panels | https://github.com/bvaughn/react-resizable-panels | Open Source | v4 renames, units, persistence | Resizable panels | A | 2026-09-15 |
| Scroll-Locked Dialogs (Master.dev) | https://blog.master.dev/scroll-locked-dialogs/ | Community | :has() scroll lock, gutter caveat | Dialogs | B | 2026-09-15 |
| Vercel Web Interface Guidelines (agent skill/AGENTS.md) | https://github.com/vercel-labs/web-interface-guidelines | Community | Focus, overscroll, deep-linking, tooltip delay rules | Community agent rules | B | 2026-09-15 |
| GoogleChrome modern-web-guidance (agent skill) | https://github.com/GoogleChrome/modern-web-guidance | Community/Official | Native tooltip recipe with polyfills | Community agent rules | B | 2026-09-15 |
| react-beautiful-dnd | https://github.com/atlassian/react-beautiful-dnd | Deprecated | Not used; flagged for migration | Avoid stale dependency | C | 2026-09-15 |

## Duplicates

| Topic | Canonical Source | Alternates Merged | Merged Into Slug |
|---|---|---|---|
| Context menus | APG Menu and Menubar | Radix/Base UI ContextMenu docs | dropdown-menus |
| Menubar (app chrome) | APG Menu and Menubar | Radix/Base UI Menubar | dropdown-menus |
| Hover cards / toggletips | MDN Popover API + WCAG 1.4.13 | Radix HoverCard, Base UI PreviewCard | popovers (hover cards), tooltips (toggletips) |
| Bottom sheets vs side drawers | NN/g Bottom Sheets + APG Dialog | shadcn Sheet, Base UI Drawer, Vaul | drawers-and-sheets |
| Scroll locking | MDN dialog + Master.dev | overscroll-behavior articles | accessible-dialogs |
| Infinite scroll / load more | GOV.UK Pagination + APG Feed | TanStack Query infinite queries | pagination (UX), list-virtualization (rendering) |
| Disclosure widget | APG Accordion / Disclosure | details/summary MDN, Chrome exclusive accordion | accordions-and-disclosure |
| Navigation tabs vs in-page tabs | APG Tabs + NN/g | GOV.UK Tabs | tabs (links cross-ref navigation-menus-and-sidebars) |
| Window splitter | APG Window Splitter | react-resizable-panels, shadcn Resizable | resizable-panels |
| Positioning of all overlays | MDN anchor positioning + Floating UI | Radix/Base UI positioner props | floating-element-positioning |
| Library-specific detail for Vaul/Sonner/cmdk | Library repos | — | referenced; canonical library coverage lives in W08 small-ui-primitives-vaul-sonner-cmdk |

## Gaps

- Web search budget was exhausted mid-research, so the survey of community `.cursor/rules` and GitHub SKILL.md files for UI components was shallow (only the Vercel Web Interface Guidelines and GoogleChrome modern-web-guidance were reviewed).
- Material 3 guidance (navigation rail/drawer, bottom sheets, carousels) wasn't retrieved. Carbon notification pages failed to fetch, and the Polaris React toast docs redirect (Polaris React appears superseded). Design-system coverage leans on GOV.UK and NN/g.
- CSS anchor positioning support data conflicts: web-features/caniuse show partial or limited support for some engine versions, while other sources claim Baseline 2026. Skills flag this and recommend fallbacks and polyfills; re-verify quarterly.
- Not re-verified: cross-engine support for `::details-content`, `interpolate-size`, `content-visibility`, `showPopover({source})`, `anchor-scope`, and Safari `hidden="until-found"`.
- dnd-kit roadmap (legacy `@dnd-kit/core` vs pre-1.0 `@dnd-kit/react`) is unresolved upstream.
- React Aria Tree's rendered role (tree vs treegrid) and React Aria Toast stable/UNSTABLE naming weren't confirmed.
- react-resizable-panels v4 exact prop shapes (`defaultLayout`, `orientation`, unit strings) were only partially confirmed.
- Embla v9 is still RC; carousel code targets v8 APIs.
- No first-hand screen reader testing matrix (NVDA/JAWS/VoiceOver/TalkBack) was performed. Guidance is from documentation.
- Candidate component skills not written (possible future slugs): steppers/progress indicators (partly W07 multi-step forms), avatars/badges/status indicators, table-of-contents/scrollspy, lightbox/image viewer.
