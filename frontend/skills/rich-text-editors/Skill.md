# Rich Text Editors

## Summary
How to choose, integrate and harden rich text editors in React and Next.js (App Router, TypeScript). Covers the editor landscape (Tiptap v3, Lexical, ProseMirror, Plate, BlockNote) and document modeling (JSON vs HTML vs Markdown). Also covers toolbars and shortcuts, paste handling, accessibility of `contenteditable`, SSR/hydration (`"use client"`, `immediatelyRender: false`, dynamic import), and form integration. Content is saved through React Hook Form or Server Actions using one shared Zod schema, validated again and sanitized on the server.

## Category
Components

## Subcategories
WYSIWYG editing, contenteditable, document schemas, toolbars and bubble menus, markdown shortcuts, slash commands, mentions, collaborative editing, HTML sanitization, SSR hydration

## Problem It Solves
Raw `contenteditable` is inconsistent across browsers. IME and mobile keyboards break naive implementations. Content pasted from Word or Google Docs carries junk markup. Storing and rendering user HTML is a direct stored-XSS vector. In Next.js, editors that initialize during SSR cause hydration errors and bloat server-rendered pages. Teams often pick the wrong tool, like a heavy block editor for a comment box, and then struggle to migrate the stored content.

## When To Use
- CMS/article authoring, knowledge bases, documentation, newsletters.
- Comments, descriptions, messages that genuinely need formatting (bold, lists, links, mentions).
- Notion-style block editors and collaborative documents.

## When Not To Use
- Plain text or short fields: textarea (see text-inputs-and-fields).
- Developers writing Markdown: textarea with preview or CodeMirror 6.
- Code editing: CodeMirror or Monaco.
- Strict structured data (addresses, specs): discrete form fields.

## Core Principles
1. Store a structured document (framework JSON) or a strictly limited HTML/Markdown subset; define the schema before features.
2. Treat all editor output as untrusted: validate on the server with the shared Zod schema, and sanitize any HTML you store or render.
3. Use a mature framework; never build on `document.execCommand` (deprecated).
4. The editor is client-only: `"use client"`, no editor instantiation during SSR, and a lightweight server-rendered read-only view.
5. Keyboard shortcuts and toolbar are both available; the toolbar is one tab stop (APG toolbar pattern).
6. The editor is labelled, identifies as a multiline textbox, and exposes formatting state.

## Best Practices
- Limit formatting to what content needs; every node/mark must be rendered, sanitized and migrated.
- Markdown input rules (`**bold**`, `# `, `- `, `1. `, `> `) and standard shortcuts (Ctrl/Cmd+B/I/U/K, undo/redo).
- Normalize paste: strip styles/classes, map Word/Docs structures to schema nodes; support Ctrl/Cmd+Shift+V plain paste.
- Links: allow only `http`, `https`, `mailto`; add `rel="noopener noreferrer nofollow"` for user content.
- Images: upload via the file-upload flow, insert by URL/ID, require alt text in the insert dialog.
- Character/word limits shown in UI and enforced by the schema on the server.
- Autosave drafts (debounced Server Action) with a visible, politely announced "Saved" status.
- Persist JSON; derive sanitized HTML at save time (cached column) or render JSON directly.
- Placeholders via extension/CSS, not real text nodes.
- Test IME (Japanese/Chinese/Korean), Android Gboard, iOS autocorrect/dictation, spellcheck.

## Implementation Guidance

### Framework decision table (Sept 2026)
| Need | Choose | Notes |
|---|---|---|
| General-purpose React editor, fast start | **Tiptap v3** (3.3x) | Headless, ProseMirror-based; MIT core, some Pro/Cloud extensions are paid |
| Maximum control over schema/transactions | **ProseMirror** | Low-level, very stable, steep learning curve |
| React-centric, performance, strong a11y focus | **Lexical** (~0.50) | Pre-1.0: minor versions can break; pin all `@lexical/*` to one version |
| shadcn/Tailwind UI kit with plugins and AI | **Plate** (`platejs` + `@platejs/*`) | Slate-based; UI installed via shadcn CLI |
| Notion-style blocks out of the box | **BlockNote** | Tiptap/ProseMirror-based, opinionated |
| Enterprise WYSIWYG with commercial support | CKEditor 5, TinyMCE | GPL or commercial licensing |

### Document storage
| Format | Pros | Cons |
|---|---|---|
| Framework JSON | Lossless, schema-checkable, easy transforms | Tied to framework; needs renderer |
| Sanitized HTML | Portable, renders anywhere | Must sanitize on every write; lossy round trips |
| Markdown | Human-readable, portable | Limited for tables, mentions, colors |

### Keyboard
| Key | Action |
|---|---|
| Ctrl/Cmd + B / I / U | Bold / italic / underline |
| Ctrl/Cmd + K | Insert/edit link |
| Ctrl/Cmd + Z, Ctrl/Cmd + Shift + Z (Ctrl+Y on Windows) | Undo / redo |
| Ctrl/Cmd + Shift + V | Paste as plain text |
| Tab / Shift+Tab inside list | Indent / outdent; elsewhere Tab leaves the editor |
| Alt+F10 (common) or documented key | Focus toolbar |
| Toolbar Arrow Left/Right, Home/End | Move between toolbar controls (roving tabindex) |
| Escape | Close bubble/slash menu, return to text |

If Tab indents everywhere, document an escape route (WCAG 2.1.2 No Keyboard Trap).

### ARIA
- Editable element: `role="textbox"`, `aria-multiline="true"`, `aria-labelledby`, `aria-describedby` (hint/error), `aria-invalid`. In Tiptap, set via `editorProps.attributes`.
- Toolbar: `role="toolbar"`, `aria-label`, `aria-controls`; toggles use `aria-pressed`.
- Slash/mention menus: listbox with `aria-activedescendant` while focus stays in the editor.

### Validation and submission architecture
| Layer | Responsibility |
|---|---|
| `lib/schemas/article.ts` (shared) | `title`, `body` (serialized doc JSON string): length limits, parseable, non-empty, `type: "doc"` |
| Client (RHF `Controller` or hidden input) | Keep `body` as a JSON string in form state; instant feedback |
| Server Action | Auth, `safeParse` with the same schema, render JSON to HTML server-side, sanitize with an allowlist, store both |
| Read-only page (Server Component) | Render stored sanitized HTML or JSON; never loads editor JS |

## Recommended Workflow
1. Define content needs: nodes/marks, embeds, max length, collaboration, output targets.
2. Pick the framework (table); check licenses of paid extensions.
3. Write the shared Zod schema and the server sanitizer allowlist first.
4. Build a client editor component with label, minimal toolbar, input rules; load it via `next/dynamic` where it isn't above the fold.
5. Integrate with forms: RHF `Controller` or Server Action hidden input; both use the shared schema, and the server re-validates.
6. Add paste normalization, link validation, image upload, autosave.
7. Build the read-only renderer as a Server Component.
8. Test IME, mobile, screen readers, Word/Docs paste, XSS payloads, direct action calls, hydration.

## Patterns

### Shared schema module
```tsx
// lib/schemas/article.ts
import { z } from "zod";

export const MAX_BODY_CHARS = 200_000;

type DocNode = { type?: string; text?: string; content?: DocNode[] };
const hasText = (n: DocNode): boolean => !!n.text?.trim() || (n.content ?? []).some(hasText);

export const parseDoc = (s: string): DocNode | null => {
  try {
    const d = JSON.parse(s) as DocNode;
    return d && d.type === "doc" && Array.isArray(d.content) ? d : null;
  } catch {
    return null;
  }
};

export const articleSchema = z.object({
  title: z.string().trim().min(1, "Enter a title").max(120, "Title must be 120 characters or fewer"),
  body: z
    .string()
    .max(MAX_BODY_CHARS, "Article is too long")
    .refine((s) => parseDoc(s) !== null, "Article body is invalid")
    .refine((s) => { const d = parseDoc(s); return !!d && hasText(d); }, "Enter the article body"),
});
export type ArticleInput = z.infer<typeof articleSchema>;
```

### Client editor component (Tiptap v3)
```tsx
// components/rich-field.tsx
"use client";
import { useEditor, EditorContent, useEditorState } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import type { KeyboardEvent } from "react";

type Props = {
  id: string;
  label: string;
  initialJson?: string;
  error?: string;
  onChange: (json: string) => void;
  onBlur?: () => void;
};

export default function RichField({ id, label, initialJson, error, onChange, onBlur }: Props) {
  const editor = useEditor({
    extensions: [StarterKit.configure({ link: { openOnClick: false, protocols: ["http", "https", "mailto"] } })],
    content: initialJson ? JSON.parse(initialJson) : undefined,
    immediatelyRender: false, // required under SSR to avoid hydration mismatch
    editorProps: {
      attributes: {
        role: "textbox", "aria-multiline": "true", "aria-labelledby": `${id}-label`,
        "aria-describedby": error ? `${id}-error` : "", "aria-invalid": error ? "true" : "false",
        class: "prose min-h-40 p-3 text-base",
      },
    },
    onUpdate: ({ editor }) => onChange(JSON.stringify(editor.getJSON())),
    onBlur: () => onBlur?.(),
  });

  const s = useEditorState({
    editor,
    selector: ({ editor }) => ({ bold: editor?.isActive("bold") ?? false, italic: editor?.isActive("italic") ?? false }),
  });

  const onToolbarKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const buttons = Array.from(e.currentTarget.querySelectorAll<HTMLButtonElement>("button"));
    const i = buttons.indexOf(document.activeElement as HTMLButtonElement);
    const next = e.key === "ArrowRight" ? i + 1 : e.key === "ArrowLeft" ? i - 1 : e.key === "Home" ? 0 : e.key === "End" ? buttons.length - 1 : null;
    if (next === null) return;
    e.preventDefault();
    const target = buttons[(next + buttons.length) % buttons.length];
    buttons.forEach((b) => (b.tabIndex = b === target ? 0 : -1));
    target.focus();
  };

  return (
    <div>
      <span id={`${id}-label`}>{label}</span>
      <div role="toolbar" aria-label={`${label} formatting`} aria-controls={id} onKeyDown={onToolbarKey}>
        <button type="button" tabIndex={0} aria-pressed={s?.bold} title="Bold (Ctrl+B)"
          onClick={() => editor?.chain().focus().toggleBold().run()}>B</button>
        <button type="button" tabIndex={-1} aria-pressed={s?.italic} title="Italic (Ctrl+I)"
          onClick={() => editor?.chain().focus().toggleItalic().run()}>I</button>
      </div>
      <EditorContent editor={editor} id={id} />
      {error && <p id={`${id}-error`} className="text-red-700">{error}</p>}
    </div>
  );
}
```
Verify the StarterKit `link` configure key against the installed 3.x version.

### Lazy loading from a client wrapper
```tsx
// components/rich-field-lazy.tsx
"use client";
import dynamic from "next/dynamic";

// ssr:false is only allowed in client components; the placeholder reserves height to avoid CLS
export const RichFieldLazy = dynamic(() => import("./rich-field"), {
  ssr: false,
  loading: () => <div className="min-h-40 rounded border" aria-hidden="true" />,
});
```

### Server Actions (re-validate, render, sanitize)
```tsx
// app/articles/actions.ts
"use server";
import { z } from "zod";
import sanitizeHtml from "sanitize-html";
import { revalidatePath } from "next/cache";
import { articleSchema, parseDoc, type ArticleInput } from "@/lib/schemas/article";
import { requireUser } from "@/lib/auth";
import { renderDocToHtml } from "@/lib/editor/render"; // wraps Tiptap's server-side HTML/static renderer with the same extensions
import { saveArticle } from "@/lib/data/articles";

export type ArticleState = { ok: boolean; errors?: Partial<Record<keyof ArticleInput, string[]>>; values?: ArticleInput };

const ALLOWED = {
  allowedTags: ["p", "br", "strong", "em", "u", "s", "a", "ul", "ol", "li", "h2", "h3", "blockquote", "code", "pre"],
  allowedAttributes: { a: ["href", "rel"] },
  allowedSchemes: ["http", "https", "mailto"],
  transformTags: { a: sanitizeHtml.simpleTransform("a", { rel: "noopener noreferrer nofollow" }) },
};

export async function saveArticleData(input: unknown): Promise<ArticleState> {
  const user = await requireUser();
  const parsed = articleSchema.safeParse(input);
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  const doc = parseDoc(parsed.data.body)!;
  const html = sanitizeHtml(renderDocToHtml(doc), ALLOWED); // defense in depth: never trust client HTML or JSON
  await saveArticle(user.id, { title: parsed.data.title, bodyJson: doc, bodyHtml: html });
  revalidatePath("/articles");
  return { ok: true };
}

export async function saveArticleAction(_prev: ArticleState, formData: FormData): Promise<ArticleState> {
  const values = { title: String(formData.get("title") ?? ""), body: String(formData.get("body") ?? "") };
  const res = await saveArticleData(values);
  return res.ok ? res : { ...res, values };
}
```

### Way 1: React Hook Form + Zod
```tsx
// app/articles/new/article-form-client.tsx
"use client";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { articleSchema, type ArticleInput } from "@/lib/schemas/article";
import { RichFieldLazy } from "@/components/rich-field-lazy";
import { saveArticleData } from "../actions";

export function ArticleFormClient() {
  const { register, control, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm<ArticleInput>({
    resolver: zodResolver(articleSchema), defaultValues: { title: "", body: "" }, mode: "onBlur",
  });

  const onSubmit = async (values: ArticleInput) => {
    const res = await saveArticleData(values); // server validates and sanitizes again
    for (const [k, msgs] of Object.entries(res.errors ?? {})) setError(k as keyof ArticleInput, { message: msgs?.[0] });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <label htmlFor="title">Title</label>
      <input id="title" aria-invalid={!!errors.title} {...register("title")} />
      {errors.title && <p className="text-red-700">{errors.title.message}</p>}

      <Controller control={control} name="body"
        render={({ field, fieldState }) => (
          // Uncontrolled editor: write to form state on update, never push state back per keystroke
          <RichFieldLazy id="body" label="Article" error={fieldState.error?.message}
            onChange={field.onChange} onBlur={field.onBlur} />
        )} />

      <button type="submit" disabled={isSubmitting}>{isSubmitting ? "Publishing…" : "Publish"}</button>
    </form>
  );
}
```

### Way 2: Server Action + useActionState / useFormStatus
```tsx
// app/articles/new/article-form-action.tsx
"use client";
import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { RichFieldLazy } from "@/components/rich-field-lazy";
import { saveArticleAction, type ArticleState } from "../actions";

function PublishButton() {
  const { pending } = useFormStatus();
  return <button type="submit" aria-disabled={pending}>{pending ? "Publishing…" : "Publish"}</button>;
}

export function ArticleFormAction() {
  const [state, formAction] = useActionState<ArticleState, FormData>(saveArticleAction, { ok: false });
  const [body, setBody] = useState(""); // editor content lives in React state, surviving the post-action form reset

  return (
    <form action={formAction} noValidate>
      <label htmlFor="title">Title</label>
      <input id="title" name="title" defaultValue={state.values?.title} aria-invalid={!!state.errors?.title} />
      {state.errors?.title && <p className="text-red-700">{state.errors.title[0]}</p>}

      <RichFieldLazy id="body" label="Article" initialJson={state.values?.body} error={state.errors?.body?.[0]} onChange={setBody} />
      <input type="hidden" name="body" value={body} />

      <PublishButton />
      <p role="status">{state.ok ? "Article published" : ""}</p>
    </form>
  );
}
```
The editor requires JavaScript. For a progressive-enhancement fallback, render a `<noscript>` textarea named `body_markdown` and handle it in the action with its own schema branch.

### Read-only rendering (Server Component)
```tsx
// app/articles/[id]/page.tsx
import { getArticle } from "@/lib/data/articles";

export default async function ArticlePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const article = await getArticle(id);
  // bodyHtml was produced and sanitized server-side at write time; no editor JS ships to readers
  return <article className="prose" dangerouslySetInnerHTML={{ __html: article.bodyHtml }} />;
}
```
Only render HTML that your own server sanitized. If content can come from any other source (imports, legacy rows), sanitize again at render.

### Collaboration
Yjs document + provider (Hocuspocus / y-websocket / Liveblocks) + awareness cursors, in a client component. Authorize every connection; store snapshots server-side; use the Yjs undo manager instead of local history.

## Anti-Patterns
- **`dangerouslySetInnerHTML` with client-submitted HTML**: stored XSS. Fix: server-side sanitize at write time (allowlist), or render from validated JSON.
- **Validating only in the browser**: Server Actions can be called with arbitrary payloads. Fix: shared schema `safeParse` plus sanitization in the action.
- **Tiptap `useEditor` without `immediatelyRender: false` in Next.js**: hydration mismatch. Fix: set it, keep the component `"use client"`, optionally `dynamic(..., { ssr: false })`.
- **`next/dynamic` with `ssr: false` in a Server Component**: build error. Fix: wrap in a client component.
- **Controlled editor (re-setting content from React state each change)**: the caret jumps and IME composition is lost. Fix: uncontrolled editor, write via `onUpdate`; use `setContent` only for external resets.
- **Editor JS on read-only pages**: large bundle for no benefit. Fix: Server Component renders stored HTML/JSON.
- **`execCommand`-based custom editor**: deprecated and inconsistent. Fix: use a framework.
- **Every toolbar button a tab stop / icon-only unnamed buttons**: slow keyboard navigation and fails WCAG 4.1.2. Fix: roving tabindex, `aria-label`/`title` with shortcut.
- **Empty doc treated as valid** (`<p></p>` or `{"type":"doc","content":[{"type":"paragraph"}]}`): passes a `min(1)` string check. Fix: text-content refinement in the schema.
- **Mixed `@lexical/*` versions**: runtime errors. Fix: pin all to one exact version.
- **Paid Tiptap Pro extensions without license review**: legal risk. Fix: check licensing.

## Accessibility
- WCAG 4.1.2 (textbox role, name, toggle state), 2.1.1 (toolbar operable by keyboard), 2.1.2 (no keyboard trap), 1.3.1 (semantic rendered output: real headings/lists), 1.1.1 (alt text for images), 2.4.7/2.4.11 (visible focus), 3.3.1/3.3.2 (errors and documented shortcuts), 4.1.3 (autosave status via `role="status"`).
- Offer "Heading 2/3" rather than H1 inside article bodies.
- Test NVDA + Chrome/Firefox, JAWS, VoiceOver macOS/iOS; contenteditable behavior differs notably.

## Responsive Design
- Mobile: toolbar collapses to overflow menu or a sticky bar above the virtual keyboard (position with `visualViewport` in an effect).
- Bubble menus must not cover the selection or native handles.
- No hover-only affordances (block drag handles): provide a visible menu button.
- Editable font-size at least 16px to prevent iOS zoom on focus.

## Performance
- `next/dynamic` / `React.lazy` the editor; reserve height to avoid CLS.
- Tiptap v3: `useEditorState` selectors; leave `shouldRerenderOnTransaction` off (v3 default) so React doesn't re-render per keystroke.
- Debounce `getJSON()` serialization and autosave (500–1000 ms) for large documents; RHF `Controller` updates can be debounced in `onUpdate`.
- Avoid React node views for every paragraph in long documents.

## Security
- Server: `safeParse` with the shared schema, check authorization, render JSON to HTML with the same extension set, sanitize with an allowlist (sanitize-html or DOMPurify + jsdom/isomorphic-dompurify), store sanitized HTML.
- Enforce link protocols and `rel` on the server, not just in the editor's link extension.
- Consider Trusted Types + CSP (`require-trusted-types-for 'script'`) to catch unsafe sinks.
- Iframe embeds only from an allowlist of hosts, with `sandbox` and `referrerpolicy`.
- Convert pasted `data:` images into uploads; reject oversized bodies via schema max length.
- Collaboration servers authorize per document connection.

## Testing
- Unit (Vitest): shared schema (empty doc, invalid JSON, too long); sanitizer against an XSS corpus (`<img onerror>`, `javascript:` links, SVG, mXSS vectors).
- Action tests: call `saveArticleData` directly with malicious JSON/HTML and assert stored HTML is clean.
- Component/E2E (Playwright): type, shortcuts, toolbar arrows, paste HTML fixtures from Word/Docs, undo/redo, submit both form variants; assert no hydration warnings in console.
- Manual IME and mobile keyboard testing on real devices.
- axe on toolbar/editor; screen reader check of role/name/toggle state.

## Tooling
- **Tiptap v3** (`@tiptap/react`, `@tiptap/pm`, `@tiptap/starter-kit`, 3.3x): Active, MIT core. Menus import from `@tiptap/react/menus`. StarterKit includes Link, Underline and TrailingNode and pins its bundled extension versions. `immediatelyRender` and `useEditorState` are the SSR/perf essentials.
- **Lexical** (~0.50): Active, MIT, pre-1.0.
- **ProseMirror**: Active, MIT.
- **Plate** (`platejs`): Active, MIT, Slate-based.
- **BlockNote**: Active; check per-package licenses.
- **CKEditor 5 / TinyMCE**: GPL or commercial.
- **sanitize-html**, **DOMPurify 3.x** / isomorphic-dompurify: sanitizers.
- **Yjs** + Hocuspocus / Liveblocks: collaboration.
- **React Hook Form** + `@hookform/resolvers`, **Zod v4**.

## Framework Notes
- **React (Vite SPA)**: no SSR, so `immediatelyRender` can stay default. Lazy-load with `React.lazy` + `Suspense`. Submit JSON via RHF to your API, where the backend re-validates with the shared schema package and sanitizes. Lexical setup uses `LexicalComposer` (`initialConfig`: namespace, nodes, onError, theme) with `RichTextPlugin`, `HistoryPlugin`, `OnChangePlugin`.
- **Next.js App Router**:
  - Editor components need `"use client"`; Tiptap needs `immediatelyRender: false`; Lexical's composer also belongs in a client component.
  - Use `next/dynamic` with `ssr: false` from a client wrapper to drop editor JS from SSR output and initial bundles.
  - Pages that display content are Server Components rendering sanitized stored HTML; mark sanitizer/render modules `import "server-only"`.
  - Save via Server Actions (shared schema + sanitize + `revalidatePath`/`revalidateTag`); autosave by calling the action from a debounced effect inside `startTransition`.
  - Server Action body limit (1 MB default) caps document size, so align `MAX_BODY_CHARS` with it or raise the limit deliberately.

## AI Agent Guidance
- Do: confirm formatting is needed; otherwise use textarea/Markdown.
- Do: check installed majors. Tiptap v2 snippets (menus from `@tiptap/react`, separately installed Link/Underline) differ from v3. Lexical APIs shift between 0.x minors. Zod v4 helpers (`z.flattenError`) differ from v3.
- Do: create the shared schema; use it in `zodResolver` and in the Server Action; sanitize on the server; render read-only views in Server Components.
- Do: set `immediatelyRender: false`, `"use client"`, and lazy-load in Next.js.
- Don't: render client-provided HTML, sync form state back into the editor per keystroke, or enable paid extensions without licensing.
- Verify before done: no hydration warnings; direct action calls with XSS payloads store clean HTML; empty doc is rejected; keyboard reaches toolbar and can leave the editor; Word paste yields clean nodes; both form variants show server errors.

## Examples

### Lexical minimal client editor
```tsx
"use client";
import { LexicalComposer } from "@lexical/react/LexicalComposer";
import { RichTextPlugin } from "@lexical/react/LexicalRichTextPlugin";
import { ContentEditable } from "@lexical/react/LexicalContentEditable";
import { HistoryPlugin } from "@lexical/react/LexicalHistoryPlugin";
import { OnChangePlugin } from "@lexical/react/LexicalOnChangePlugin";
import { LexicalErrorBoundary } from "@lexical/react/LexicalErrorBoundary";

export function NotesEditor({ onChange }: { onChange: (json: string) => void }) {
  return (
    <LexicalComposer initialConfig={{ namespace: "notes", nodes: [], onError: (e: Error) => { throw e; } }}>
      <RichTextPlugin
        contentEditable={<ContentEditable aria-label="Notes" aria-multiline="true" className="min-h-40 p-3" />}
        ErrorBoundary={LexicalErrorBoundary} />
      <HistoryPlugin />
      <OnChangePlugin onChange={(state) => onChange(JSON.stringify(state.toJSON()))} />
    </LexicalComposer>
  );
}
```
A Lexical JSON body needs its own schema refinement (root node shape) instead of the Tiptap `type: "doc"` check.

## Related Skills
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — Controller integration and shared schemas
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — saving, authorization, revalidation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState / useFormStatus
- [nextjs-server-component-patterns](../nextjs-server-component-patterns/Skill.md) — client/server boundaries for editors
- [code-splitting-and-lazy-loading](../code-splitting-and-lazy-loading/Skill.md) — next/dynamic and React.lazy
- [hydration-strategies](../hydration-strategies/Skill.md) — avoiding hydration mismatches
- [text-inputs-and-fields](../text-inputs-and-fields/Skill.md) — textarea alternative and labeling
- [file-upload](../file-upload/Skill.md) — image/attachment transport
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — XSS and sanitization
- [content-security-policy](../content-security-policy/Skill.md) — Trusted Types
- [search-and-autocomplete](../search-and-autocomplete/Skill.md) — mention/slash menu listbox behavior
- [realtime-collaboration-ui](../realtime-collaboration-ui/Skill.md) — Yjs presence and cursors
- [keyboard-navigation](../keyboard-navigation/Skill.md) — toolbar roving tabindex

## Sources
- [Tiptap React install docs](https://tiptap.dev/docs/editor/getting-started/install/react) — Official — useEditor, immediatelyRender, useEditorState, menus subpath, Next.js notes
- [Tiptap 3.0 is stable](https://tiptap.dev/blog/release-notes/tiptap-3-0-is-stable) — Official — v3 changes, StarterKit contents
- [Tiptap releases](https://github.com/ueberdosis/tiptap/releases) — Open Source — current 3.3x versions, StarterKit pinning
- [Lexical GitHub](https://github.com/facebook/lexical) — Open Source — current 0.x version, React plugin model
- [ProseMirror guide](https://prosemirror.net/docs/guide/) — Open Source — schema/transaction model
- [Plate docs](https://platejs.org/docs) — Open Source — `platejs` package structure, shadcn UI
- [WAI-ARIA APG Toolbar pattern](https://www.w3.org/WAI/ARIA/apg/patterns/toolbar/) — Official — toolbar keyboard model
- [DOMPurify](https://github.com/cure53/DOMPurify) — Open Source — sanitizer configuration
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) — Official — HTML sanitization guidance

## License / Usage Notes
Tiptap core (MIT; Pro extensions commercial), Lexical (MIT), ProseMirror (MIT), Plate (MIT), sanitize-html (MIT), DOMPurify (Apache-2.0/MPL-2.0), React Hook Form (MIT), Zod (MIT), CKEditor 5/TinyMCE (GPL or commercial). Summarized; code is original. `renderDocToHtml` is a local wrapper whose Tiptap server import path must be verified for the installed version.

## Quality Tier
A — verified current Tiptap v3 React/SSR APIs and Lexical version plus official APG/OWASP guidance. Tiptap's server-side HTML renderer entry point, Plate and BlockNote details were not deeply re-verified.

## Status
Active

## Last Verified
2026-09-15
