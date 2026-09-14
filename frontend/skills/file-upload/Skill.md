# File Upload

## Summary
How to build accessible, resilient and secure file upload UIs in React and Next.js (App Router, TypeScript). A labelled `<input type="file">` is the foundation, with drop zones added as progressive enhancement. Each file gets its own progress, error and retry state. The same Zod schema validates on the client and again on the server. Large files go directly to storage via presigned or resumable (tus / S3 multipart) uploads, which avoids Server Action body limits. Covers react-dropzone v20, Uppy 5 (headless components and hooks), and server-side verification.

## Category
Components

## Subcategories
File input, dropzone, upload progress, resumable uploads, presigned URLs, Server Action file handling, image preview, avatar upload, attachment lists, camera capture

## Problem It Solves
Uploads fail in many ways: wrong type, too large, flaky mobile networks, a tab closed mid-upload, platform body-size limits. Custom drop zones often remove the keyboard and screen reader path entirely. Next.js Server Actions accept `File` in `FormData` but are capped at 1 MB by default and by hosting limits. Upload endpoints are also a major attack surface: stored XSS via SVG/HTML, path traversal, malware, and runaway storage costs.

## When To Use
- Attachments on forms (documents, receipts, evidence).
- Avatar/profile image upload with crop.
- Bulk media upload (galleries, CMS).
- Large files (video, datasets) needing resume and chunking.

## When Not To Use
- Structured data import with column mapping and validation reports: see data-import-export-ui.
- Reordering items on the page: see drag-and-drop.
- Pasting small text: use a textarea.
- Inline images in rich text: the editor owns insertion UI (see rich-text-editors), but the transport guidance here still applies.

## Core Principles
1. A real, labelled `<input type="file">` is always present and operable; dragging is an optional shortcut.
2. One shared Zod schema module defines limits (types, size, count) and form shape; client checks give fast feedback, and the server re-validates and inspects file content.
3. Every file has a visible state: queued, uploading (%), processing, done, failed (reason + retry), removable.
4. Upload on selection and submit server-issued file IDs, not bytes, with the form.
5. Bytes go directly to object storage (presigned/tus) for anything beyond small files; Server Actions handle metadata.
6. State limits up front (formats, max size, max count) before the user picks files.

## Best Practices
- Label "Upload a file" with hint "PDF, JPG or PNG, up to 10 MB each, max 5 files".
- `accept` lists MIME types and extensions (`accept="image/png,image/jpeg,.pdf"`). It is only a hint: users can bypass it.
- `capture="environment"` only when a camera photo is the intended input.
- Show filename, size, type icon/thumbnail, `<progress>`, and a Remove button named "Remove invoice.pdf".
- Errors name the file and the rule: "photo.heic is not an accepted format. Upload a JPG or PNG."
- Announce added/failed/complete in a polite `role="status"` region; don't announce every percent.
- Keep uploaded files across validation errors on other fields (IDs in form state survive re-renders and action resets).
- Warn on navigation while uploads are in flight (`beforeunload`); resume where supported.
- Thumbnails: `URL.createObjectURL` in an effect, revoke in cleanup.
- Strip EXIF location server-side when privacy matters.
- Support paste-from-clipboard for images where screenshots are common.

## Implementation Guidance

### Transport decision table
| Scenario | Approach |
|---|---|
| Tiny files (< ~1 MB, e.g., avatar) and simple backend | Server Action receiving `File` in `FormData`, validated with `z.file()`; raise `experimental.serverActions.bodySizeLimit` only moderately (verify the config key for your Next.js version; hosts also cap bodies, e.g., Vercel Functions ~4.5 MB) |
| Medium files | Server Action issues a presigned POST/PUT per file; browser uploads directly to S3/GCS/R2 with XHR progress |
| Large files / mobile / unreliable networks | tus resumable (tusd + Uppy Tus) or S3 multipart with presigned parts |
| Needs scanning/transcoding | Upload to quarantine bucket, then server-side scan/process, then promote; UI shows "Processing" |

`fetch` still lacks broadly supported upload progress; use `XMLHttpRequest.upload.onprogress` or Uppy/tus-js-client.

### Per-file state
Model as a discriminated union: `{ status: "uploading"; progress } | { status: "done"; fileId } | { status: "failed"; error; retryable }`. Avoid parallel booleans.

### Keyboard and ARIA
| Element | Behavior |
|---|---|
| "Choose files" button / input | Tab-focusable; Enter/Space opens OS picker |
| Drop zone | Wraps the button; not itself a separate focus stop |
| Remove / Retry / Cancel | Per-file buttons named with the filename |
| Progress | `<progress value max aria-label="Uploading invoice.pdf">` |
| Status | `role="status"` announcing "invoice.pdf uploaded" / "photo.heic rejected: format" |

If you visually hide the input, keep a real `<button>` that calls `input.click()` (react-dropzone `open()`), or a `<label htmlFor>` styled as a button.

### Validation and submission architecture
| Layer | Responsibility |
|---|---|
| `lib/schemas/claim.ts` (shared) | `uploadRequestSchema` (name/size/type limits), `claimSchema` (form fields + `attachmentIds`) |
| `createUploadUrl` Server Action | Auth, `uploadRequestSchema.safeParse`, server-generated key, presigned POST with size/type conditions |
| Storage finalize step | Verify object exists, magic bytes match, scan; mark `fileId` ready for this user |
| `submitClaim` Server Action | Auth, `claimSchema.safeParse`, confirm every `attachmentId` belongs to the user and is ready |
| Client (RHF or `useActionState`) | Same schemas for instant feedback; per-file UI |

## Recommended Workflow
1. Define constraints with product/security: types (by content), max size, count, retention, scanning.
2. Write the shared schema module with exported constants (`MAX_BYTES`, `ALLOWED_TYPES`) used by UI hints, `accept`, dropzone options and server checks.
3. Choose transport (table) and implement the presign/finalize server code with auth.
4. Build the input + file list with states; add drop zone and paste.
5. Integrate with the form both ways: RHF (`setValue("attachmentIds")`) or Server Action form (hidden `attachmentIds` inputs).
6. Test keyboard/screen reader, slow network throttling, offline mid-upload, spoofed and oversize files, direct calls to actions.

## Patterns

### Shared schema module
```tsx
// lib/schemas/claim.ts
import { z } from "zod";

export const MAX_BYTES = 10 * 1024 * 1024;
export const MAX_FILES = 5;
export const ALLOWED_TYPES = ["application/pdf", "image/png", "image/jpeg"] as const;
export const ACCEPT_ATTR = ".pdf,.png,.jpg,.jpeg,application/pdf,image/png,image/jpeg";

export const uploadRequestSchema = z.object({
  name: z.string().min(1).max(255),
  size: z.number().int().positive().max(MAX_BYTES, "File must be 10 MB or smaller"),
  type: z.enum(ALLOWED_TYPES, "Upload a PDF, PNG or JPG"),
});
export type UploadRequest = z.infer<typeof uploadRequestSchema>;

export const claimSchema = z.object({
  description: z.string().trim().min(1, "Enter a description").max(500, "Description must be 500 characters or fewer"),
  attachmentIds: z.array(z.uuid()).min(1, "Upload at least one document").max(MAX_FILES, `Upload up to ${MAX_FILES} documents`),
});
export type ClaimInput = z.infer<typeof claimSchema>;

// Small-file variant for direct Server Action upload (avatar)
export const avatarSchema = z.object({
  avatar: z.file().max(1024 * 1024, "Image must be 1 MB or smaller").mime(["image/png", "image/jpeg"], "Upload a PNG or JPG"),
});
```

### Server Actions: presign and submit
```tsx
// app/claims/actions.ts
"use server";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { S3Client } from "@aws-sdk/client-s3";
import { createPresignedPost } from "@aws-sdk/s3-presigned-post";
import { claimSchema, uploadRequestSchema, MAX_BYTES, type ClaimInput } from "@/lib/schemas/claim";
import { requireUser } from "@/lib/auth";
import { recordPendingUpload, attachmentsReadyForUser, createClaim } from "@/lib/data/claims";

const s3 = new S3Client({}); // credentials from the server environment, never the client

export async function createUploadUrl(input: unknown) {
  const user = await requireUser();
  const parsed = uploadRequestSchema.safeParse(input);
  if (!parsed.success) return { ok: false as const, error: parsed.error.issues[0]?.message ?? "Invalid file" };

  const fileId = randomUUID();
  const key = `quarantine/${user.id}/${fileId}`; // never use the user's filename as the key
  const { url, fields } = await createPresignedPost(s3, {
    Bucket: process.env.UPLOAD_BUCKET!,
    Key: key,
    Conditions: [["content-length-range", 1, MAX_BYTES], ["eq", "$Content-Type", parsed.data.type]],
    Fields: { "Content-Type": parsed.data.type },
    Expires: 300,
  });
  await recordPendingUpload({ fileId, userId: user.id, key, originalName: parsed.data.name });
  return { ok: true as const, fileId, url, fields };
}

export type ClaimState = { ok: boolean; errors?: Partial<Record<keyof ClaimInput, string[]>>; description?: string };

export async function submitClaim(input: unknown): Promise<ClaimState> {
  const user = await requireUser();
  const parsed = claimSchema.safeParse(input);
  if (!parsed.success) return { ok: false, errors: z.flattenError(parsed.error).fieldErrors };
  // Ownership + readiness (finalize step verified magic bytes and scan result)
  if (!(await attachmentsReadyForUser(user.id, parsed.data.attachmentIds))) {
    return { ok: false, errors: { attachmentIds: ["One or more documents are still processing or invalid"] } };
  }
  await createClaim(user.id, parsed.data);
  return { ok: true };
}

export async function submitClaimAction(_prev: ClaimState, formData: FormData): Promise<ClaimState> {
  const values = {
    description: String(formData.get("description") ?? ""),
    attachmentIds: formData.getAll("attachmentIds").map(String),
  };
  const res = await submitClaim(values);
  return res.ok ? res : { ...res, description: values.description };
}
```

### Reusable uploader (react-dropzone, direct-to-storage)
```tsx
// app/claims/attachments.tsx
"use client";
import { useCallback, useState } from "react";
import { useDropzone, type FileRejection } from "react-dropzone";
import { ALLOWED_TYPES, MAX_BYTES, MAX_FILES } from "@/lib/schemas/claim";
import { createUploadUrl } from "./actions";

type Item =
  | { key: string; name: string; status: "uploading"; progress: number }
  | { key: string; name: string; status: "done"; fileId: string }
  | { key: string; name: string; status: "failed"; error: string };

function postToStorage(url: string, fields: Record<string, string>, file: File, onProgress: (p: number) => void) {
  return new Promise<void>((resolve, reject) => {
    const body = new FormData();
    Object.entries(fields).forEach(([k, v]) => body.append(k, v));
    body.append("file", file); // must be last for S3 POST
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = (e) => e.lengthComputable && onProgress(Math.round((e.loaded / e.total) * 100));
    xhr.onload = () => (xhr.status < 300 ? resolve() : reject(new Error("Upload failed. Try again.")));
    xhr.onerror = () => reject(new Error("Network error. Check your connection and retry."));
    xhr.open("POST", url);
    xhr.send(body);
  });
}

export function Attachments({ onChange, error }: { onChange: (fileIds: string[]) => void; error?: string }) {
  const [items, setItems] = useState<Item[]>([]);
  const [announce, setAnnounce] = useState("");

  const update = useCallback((next: (xs: Item[]) => Item[]) => {
    setItems((xs) => {
      const out = next(xs);
      onChange(out.flatMap((i) => (i.status === "done" ? [i.fileId] : [])));
      return out;
    });
  }, [onChange]);

  const upload = useCallback(async (file: File) => {
    const key = crypto.randomUUID();
    update((xs) => [...xs, { key, name: file.name, status: "uploading", progress: 0 }]);
    const res = await createUploadUrl({ name: file.name, size: file.size, type: file.type }); // server re-validates
    if (!res.ok) {
      update((xs) => xs.map((x) => (x.key === key ? { key, name: file.name, status: "failed", error: res.error } : x)));
      setAnnounce(`${file.name} rejected: ${res.error}`);
      return;
    }
    try {
      await postToStorage(res.url, res.fields, file, (p) =>
        update((xs) => xs.map((x) => (x.key === key ? { key, name: file.name, status: "uploading", progress: p } : x))));
      update((xs) => xs.map((x) => (x.key === key ? { key, name: file.name, status: "done", fileId: res.fileId } : x)));
      setAnnounce(`${file.name} uploaded`);
    } catch (e) {
      update((xs) => xs.map((x) => (x.key === key ? { key, name: file.name, status: "failed", error: (e as Error).message } : x)));
      setAnnounce(`${file.name} failed to upload`);
    }
  }, [update]);

  const onDrop = useCallback((accepted: File[], rejected: FileRejection[]) => {
    rejected.forEach((r) => setAnnounce(`${r.file.name} rejected: ${r.errors[0]?.message}`));
    accepted.forEach(upload);
  }, [upload]);

  const { getRootProps, getInputProps, isDragActive, open } = useDropzone({
    onDrop, noClick: true, noKeyboard: true, maxSize: MAX_BYTES, maxFiles: MAX_FILES,
    accept: Object.fromEntries(ALLOWED_TYPES.map((t) => [t, []])),
  });

  return (
    <div>
      <p id="att-hint">PDF, PNG or JPG, up to 10 MB each, max {MAX_FILES} files.</p>
      {error && <p id="att-error" className="text-red-700"><span className="sr-only">Error: </span>{error}</p>}
      <div {...getRootProps({ className: isDragActive ? "border-2 border-dashed border-blue-600 p-6" : "border-2 border-dashed p-6" })}>
        <input {...getInputProps({ id: "attachments", "aria-describedby": error ? "att-hint att-error" : "att-hint" })} />
        <button type="button" onClick={open} className="min-h-11">Choose files</button>
        <span className="pointer-coarse:hidden"> or drop them here</span>
      </div>
      <ul aria-label="Attachments">
        {items.map((it) => (
          <li key={it.key} className="flex items-center gap-3">
            <span>{it.name}</span>
            {it.status === "uploading" && <progress max={100} value={it.progress} aria-label={`Uploading ${it.name}`} />}
            {it.status === "failed" && <span className="text-red-700">{it.error}</span>}
            <button type="button" className="min-h-11" aria-label={`Remove ${it.name}`}
              onClick={() => update((xs) => xs.filter((x) => x.key !== it.key))}>Remove</button>
          </li>
        ))}
      </ul>
      <div role="status" aria-live="polite" className="sr-only">{announce}</div>
    </div>
  );
}
```
`noClick`/`noKeyboard` keep the root from acting as a fake button; the real `<button>` is the control. Add a Retry button for `failed` items that re-calls `upload` with the retained `File`.

### Way 1: React Hook Form + Zod
```tsx
// app/claims/claim-form-client.tsx
"use client";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { claimSchema, type ClaimInput } from "@/lib/schemas/claim";
import { submitClaim } from "./actions";
import { Attachments } from "./attachments";

export function ClaimFormClient() {
  const { register, control, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm<ClaimInput>({
    resolver: zodResolver(claimSchema), defaultValues: { description: "", attachmentIds: [] },
  });

  const onSubmit = async (values: ClaimInput) => {
    const res = await submitClaim(values); // server validates again
    for (const [name, msgs] of Object.entries(res.errors ?? {})) setError(name as keyof ClaimInput, { message: msgs?.[0] });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <label htmlFor="description">Describe what happened</label>
      <textarea id="description" aria-invalid={!!errors.description} {...register("description")} />
      {errors.description && <p className="text-red-700">{errors.description.message}</p>}

      <fieldset>
        <legend>Supporting documents</legend>
        <Controller control={control} name="attachmentIds"
          render={({ field, fieldState }) => (
            <Attachments onChange={field.onChange} error={fieldState.error?.message} />
          )} />
      </fieldset>

      <button type="submit" disabled={isSubmitting}>{isSubmitting ? "Submitting…" : "Submit claim"}</button>
    </form>
  );
}
```

### Way 2: Server Action + useActionState / useFormStatus
```tsx
// app/claims/claim-form-action.tsx
"use client";
import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { submitClaimAction, type ClaimState } from "./actions";
import { Attachments } from "./attachments";

function SubmitButton({ uploading }: { uploading: boolean }) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" aria-disabled={pending || uploading}>
      {pending ? "Submitting…" : uploading ? "Waiting for uploads…" : "Submit claim"}
    </button>
  );
}

export function ClaimFormAction() {
  const [state, formAction] = useActionState<ClaimState, FormData>(submitClaimAction, { ok: false });
  const [fileIds, setFileIds] = useState<string[]>([]);
  return (
    <form action={formAction} noValidate>
      <label htmlFor="description">Describe what happened</label>
      <textarea id="description" name="description" defaultValue={state.description} aria-invalid={!!state.errors?.description} />
      {state.errors?.description && <p className="text-red-700">{state.errors.description[0]}</p>}

      <fieldset>
        <legend>Supporting documents</legend>
        {/* uploader state lives in React state, so it survives the post-action form reset */}
        <Attachments onChange={setFileIds} error={state.errors?.attachmentIds?.[0]} />
        {fileIds.map((id) => <input key={id} type="hidden" name="attachmentIds" value={id} />)}
      </fieldset>

      <SubmitButton uploading={false} />
      <p role="status">{state.ok ? "Claim submitted" : ""}</p>
    </form>
  );
}
```
Here file bytes never pass through the Server Action, so body limits don't apply. Only the IDs do. The uploader itself needs JavaScript. For a no-JS fallback, render a plain `<input type="file" name="avatar">` posting to a small-file action.

### Small file straight through a Server Action
```tsx
// app/profile/avatar-actions.ts
"use server";
import { fileTypeFromBuffer } from "file-type";
import { avatarSchema } from "@/lib/schemas/claim";
import { requireUser } from "@/lib/auth";

export async function uploadAvatar(_prev: { error?: string; ok?: boolean }, formData: FormData) {
  const user = await requireUser();
  const parsed = avatarSchema.safeParse({ avatar: formData.get("avatar") });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message };
  const bytes = Buffer.from(await parsed.data.avatar.arrayBuffer());
  const sniffed = await fileTypeFromBuffer(bytes); // don't trust File.type
  if (!sniffed || !["image/png", "image/jpeg"].includes(sniffed.mime)) return { error: "Upload a PNG or JPG" };
  // re-encode (e.g., sharp) to strip metadata/payloads, then store under a server-generated key for user.id
  return { ok: true };
}
```

### Avatar with crop
Pick a file, show a local preview (object URL), crop in a dialog with keyboard-operable handles or numeric inputs, export a Blob via canvas, then upload the Blob as a `File` through the same presign flow.

## Anti-Patterns
- **Drop zone only, input hidden, no button**: no keyboard or AT path. Fix: a visible button that calls `open()`.
- **Sending large files through Server Actions or Route Handlers**: hits body limits, memory pressure and timeouts. Fix: presigned/tus direct upload.
- **Validating only in the client resolver**: actions are callable directly. Fix: `safeParse` in every action plus ownership checks on `attachmentIds`.
- **Trusting `accept`, extension or `File.type`**: all can be spoofed. Fix: sniff magic bytes server-side, re-encode images, scan.
- **Serving uploads from the app origin with the original Content-Type**: SVG/HTML files become stored XSS. Fix: a separate domain/bucket, `Content-Disposition: attachment` for non-images, `X-Content-Type-Options: nosniff`.
- **User filename as storage key**: path traversal and overwrites. Fix: server-generated keys; keep the name as metadata.
- **Single spinner for all files**: users can't tell which file failed. Fix: per-file state and retry.
- **Keeping `File` objects only in uncontrolled inputs of an action form**: React 19 resets the form after the action and the selection is lost. Fix: upload early and keep IDs in state.
- **Announcing every progress tick**: floods screen readers. Fix: announce start, completion and failure.
- **Leaking object URLs**: memory grows in galleries. Fix: revoke in effect cleanup.
- **Storage credentials in `NEXT_PUBLIC_*` env vars**: exposed to every visitor. Fix: server-only env, presigned scoped URLs.

## Accessibility
- WCAG 2.1.1 keyboard, 4.1.2 name/role/value (button, progress), 3.3.1/3.3.3 file-specific errors, 4.1.3 status messages, 2.5.7 dragging movements (non-drag alternative: the button), 2.5.8 target size for Remove/Retry, 1.4.1 no color-only failed state.
- After removing a file, move focus to the next item's Remove button or back to "Choose files".
- Include filenames as text, not thumbnails alone.
- Error summary links should target the "Choose files" button (the focusable control).

## Responsive Design
- On touch (`pointer: coarse`) hide "or drop them here" copy; keep a large "Choose files" button.
- Mobile pickers offer camera/gallery/files automatically; `accept="image/*"` shows photo options.
- HEIC from iOS: accept and convert server-side, or state the limitation.
- File list: single column on narrow screens; thumbnail grid on wide containers.

## Performance
- Parallel uploads with a concurrency cap (3–6); chunk large files (tus/S3 multipart).
- Resize/compress images client-side when originals aren't needed (`createImageBitmap` + `OffscreenCanvas` in a worker).
- Lazy-load heavy UIs (Uppy Dashboard, image editor) with `next/dynamic` / `React.lazy` when opened.
- Hash large files in a Web Worker for dedup.

## Security
- Authenticate and authorize presign issuance; short expiry; bind `content-length-range` and Content-Type.
- Quarantine, then verify magic bytes, virus-scan, and re-encode images before marking ready.
- Serve user content from a sandboxed origin/CDN; never inline-render untrusted HTML/SVG.
- Rate-limit and quota per user.
- Server Actions: validate, authorize, and check resource ownership inside every action; don't rely on the UI hiding buttons.
- Escape filenames in UI; strip control characters.

## Testing
- Unit (Vitest): shared schema accepts/rejects sizes, types, counts, and non-UUID IDs.
- Component: `userEvent.upload(input, file)` for accepted/rejected lists and messages; mock `createUploadUrl`.
- Action tests: call `createUploadUrl`/`submitClaim` directly with oversize sizes, foreign `attachmentIds`, and malformed payloads.
- Playwright: `setInputFiles()`, synthetic `DataTransfer` drop, `page.route` for 403/500 and slow responses, offline toggling.
- Security: spoofed MIME, polyglots, SVG with script, zero-byte, `../` filenames.
- Manual screen reader pass for add/remove/fail announcements.

## Tooling
- **react-dropzone** v20.x: Active; `useDropzone` with `getRootProps`/`getInputProps`/`open`, `accept` object map, `maxSize`, `maxFiles`, `fileRejections`. UI and transport are yours.
- **Uppy 5.x** (`@uppy/core`, `@uppy/react` 5.2): Active. Headless components (`Dropzone`, `FilesList`, `FilesGrid`, `UploadButton`, `Thumbnail`) and hooks (`useDropzone`, `useFileInput`, `useRemoteSource`, `useWebcam`, `useScreenCapture`, `useUppyState`, `useUppyEvent`). v5 breaking changes: subpath imports (`@uppy/react/dashboard`), CSS at `/css/styles.min.css`; `@uppy/drag-drop`, `@uppy/file-input`, `@uppy/progress-bar` and `@uppy/redux` are deprecated. Transport: `@uppy/tus`, `@uppy/aws-s3`, `@uppy/xhr-upload`.
- **tus** (tus-js-client, tusd): Active open protocol for resumable uploads.
- **@aws-sdk/s3-presigned-post** / `@aws-sdk/s3-request-presigner`: presigned POST/PUT; R2 and MinIO are S3-compatible.
- **file-type**: magic-byte sniffing; **sharp**: server image re-encoding.
- **Zod v4** `z.file()` with `.max()` / `.mime()`; **React Hook Form** + `@hookform/resolvers`.
- **UploadThing**: hosted uploads with Next.js helpers. **FilePond**: plugin-based alternative.

## Framework Notes
- **React (Vite SPA)**: no Server Actions. Request presigned URLs from your API (fetch/tRPC) with the shared `uploadRequestSchema` validated on the backend; RHF flow is identical otherwise. Create an Uppy instance once with `useState(() => new Uppy())` and call `destroy()` on unmount.
- **Next.js App Router**:
  - Uploader components are client components; pages stay Server Components.
  - Server Actions default to a 1 MB body limit (`experimental.serverActions.bodySizeLimit` to change; verify for your version), and hosting platforms impose their own caps. Reserve direct `File` uploads through actions for small files.
  - Presign in a Server Action (as above) or a Route Handler (`app/api/uploads/route.ts`) when third-party clients or Uppy's S3 plugin need an HTTP endpoint.
  - Storage finalize webhooks/events go to Route Handlers; verify signatures.
  - `revalidatePath`/`revalidateTag` after the claim is created.
  - Keep secrets in server-only env vars; mark server data modules with `import "server-only"`.

## AI Agent Guidance
- Do: start from a labelled native input plus visible button; wrap with a drop zone.
- Do: create a shared schema module with exported limits and use it for `accept`, dropzone options, `zodResolver`, and every Server Action.
- Do: choose presigned/tus for anything over ~1 MB; submit file IDs; check ownership and readiness server-side.
- Do: check Uppy's major version (v4 root imports and `dist` CSS paths break in v5) and Zod v4 (`z.file`, `z.uuid`, `z.flattenError`).
- Don't: `display:none` the input without a keyboard-operable replacement; don't route large files through Server Actions; don't put storage keys in client env.
- Verify before done: keyboard-only upload works; rejection messages name file and rule; network failure shows retry; direct action calls with bad data are rejected; spoofed types are rejected server-side; object URLs are revoked; no hydration warnings.

## Examples

### Uppy 5 with tus (client component)
```tsx
"use client";
import { useEffect, useState } from "react";
import Uppy from "@uppy/core";
import Tus from "@uppy/tus";
import { UppyContextProvider, Dropzone, FilesList, UploadButton, useUppyEvent } from "@uppy/react";

export function VideoUploader({ onUploaded }: { onUploaded: (uploadUrl: string) => void }) {
  const [uppy] = useState(() =>
    new Uppy({ restrictions: { maxFileSize: 5 * 1024 ** 3, allowedFileTypes: ["video/*"] } })
      .use(Tus, { endpoint: "/api/tus", chunkSize: 50 * 1024 * 1024, retryDelays: [0, 1000, 3000, 5000] }));

  useEffect(() => () => uppy.destroy(), [uppy]);
  useUppyEvent(uppy, "upload-success", (file, response) => {
    if (response?.uploadURL) onUploaded(response.uploadURL);
  });

  return (
    <UppyContextProvider uppy={uppy}>
      <Dropzone />
      <FilesList />
      <UploadButton />
    </UppyContextProvider>
  );
}
```
Load with `next/dynamic` from a client wrapper to keep Uppy out of the initial bundle. Verify export paths and the event callback signature against the installed 5.x version, and audit the headless components' accessible names before shipping.

## Related Skills
- [react-hook-form-and-zod](../react-hook-form-and-zod/Skill.md) — resolver, Controller, shared schemas
- [nextjs-server-actions](../nextjs-server-actions/Skill.md) — body limits, authorization, revalidation
- [react-19-actions-and-transitions](../react-19-actions-and-transitions/Skill.md) — useActionState / useFormStatus
- [nextjs-route-handlers](../nextjs-route-handlers/Skill.md) — presign/tus/webhook endpoints
- [nextjs-env-and-config-security](../nextjs-env-and-config-security/Skill.md) — keeping storage secrets server-only
- [drag-and-drop](../drag-and-drop/Skill.md) — drop target feedback
- [data-import-export-ui](../data-import-export-ui/Skill.md) — CSV/XLSX import flows
- [form-validation-patterns](../form-validation-patterns/Skill.md) — error summaries and field errors
- [live-regions-and-announcements](../live-regions-and-announcements/Skill.md) — status announcements
- [frontend-security-fundamentals](../frontend-security-fundamentals/Skill.md) — untrusted content
- [rich-text-editors](../rich-text-editors/Skill.md) — inline image upload
- [browser-apis-in-react](../browser-apis-in-react/Skill.md) — object URLs, workers, clipboard
- [buttons-and-actions](../buttons-and-actions/Skill.md) — pending/disabled button states

## Sources
- [MDN input type=file](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file) — Official — accept as hint, capture, multiple, webkitdirectory, fakepath
- [Uppy 5.0 announcement](https://uppy.io/blog/uppy-5.0/) — Open Source — headless components/hooks, breaking changes
- [@uppy/react on npm](https://www.npmjs.com/package/@uppy/react) — Open Source — current 5.2 version
- [react-dropzone](https://github.com/react-dropzone/react-dropzone) — Open Source — useDropzone API, accept object, v20
- [tus resumable upload protocol](https://tus.io/protocols/resumable-upload) — Open Source — resumable semantics
- [GOV.UK Design System: File upload](https://design-system.service.gov.uk/components/file-upload/) — Official — labels, hints, error wording
- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html) — Official — server validation, storage, serving
- [Next.js Server Actions config (serverActions)](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions) — Official — body size limit configuration

## License / Usage Notes
Uppy (MIT), react-dropzone (MIT), tus-js-client/tusd (MIT), AWS SDK (Apache-2.0), file-type (MIT), React Hook Form (MIT), Zod (MIT), OWASP (CC BY-SA), GOV.UK (MIT/OGL). Summarized, not copied; code is original and should be checked against installed versions.

## Quality Tier
A — combines official security/HTML guidance with verified current library majors (Uppy 5, react-dropzone 20). The exact `serverActions.bodySizeLimit` config location and Uppy headless component a11y output were not re-verified this cycle.

## Status
Active

## Last Verified
2026-09-15
