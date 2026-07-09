"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  updatePost, togglePostPublished, deletePost,
  uploadPostCover, removePostCover, type Result,
} from "../actions";
import { IconCheck, IconExternal, IconTrash } from "../../_icons";

export type PostRow = {
  slug: string;
  title: string;
  excerpt: string | null;
  body: string;
  cover_url: string | null;
  published: boolean;
  published_at: string | null;
  seo_title: string | null;
  seo_description: string | null;
  updated_at: string;
};

const input =
  "w-full rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60";
const area = input + " font-mono text-[13px] leading-relaxed";
const micro = "mb-1 block text-[10px] uppercase tracking-wider text-faint";
const saveBtn =
  "rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20 disabled:opacity-40";

function Msg({ m }: { m: { ok: boolean; text: string } | null }) {
  if (!m) return null;
  return (
    <span className={"inline-flex items-center gap-1 text-[11px] " + (m.ok ? "text-live" : "text-bad")}>
      {m.ok && <IconCheck size={11} />}
      {m.text}
    </span>
  );
}

function Cover({ post }: { post: PostRow }) {
  const [preview, setPreview] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const run = (fd: FormData, fn: (f: FormData) => Promise<Result>, okText: string, after?: () => void) =>
    start(async () => {
      const r = await fn(fd);
      setMsg(r.ok ? { ok: true, text: okText } : { ok: false, text: r.error ?? "Failed" });
      if (r.ok) after?.();
    });

  function pick(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    setMsg(null);
    setPreview(f ? URL.createObjectURL(f) : null);
  }
  function upload(fd: FormData) {
    fd.set("slug", post.slug);
    run(fd, uploadPostCover, "Uploaded", () => { if (fileRef.current) fileRef.current.value = ""; });
  }
  function remove() {
    const fd = new FormData();
    fd.set("slug", post.slug);
    fd.set("url", post.cover_url ?? "");
    run(fd, removePostCover, "Removed");
  }

  return (
    <div className="flex items-start gap-4">
      <div className="overflow-hidden rounded-lg border border-line bg-panel2" style={{ aspectRatio: "16 / 8", width: 200 }}>
        {preview ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={preview} alt="" className="h-full w-full object-cover" />
        ) : post.cover_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={post.cover_url} alt="" className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-[11px] text-faint">No cover</div>
        )}
      </div>
      <div className="flex flex-col gap-2">
        <span className={micro}>Cover image</span>
        <form action={upload} className="flex items-center gap-2">
          <input ref={fileRef} type="file" name="file" accept="image/png,image/webp,image/jpeg" required onChange={pick}
            className="w-40 text-xs text-faint file:mr-2 file:rounded file:border file:border-line file:bg-panel2 file:px-2 file:py-1 file:text-xs file:text-mute" />
          <button disabled={pending} className="rounded-md border border-gold/50 bg-gold/10 px-3 py-1.5 text-xs font-medium text-gold hover:bg-gold/20 disabled:opacity-40">
            {pending ? "…" : "Upload"}
          </button>
        </form>
        <Msg m={msg} />
        {post.cover_url && (
          <button onClick={remove} disabled={pending} className="text-left text-xs text-faint hover:text-bad disabled:opacity-40">
            Remove
          </button>
        )}
      </div>
    </div>
  );
}

export function PostEditor({ post }: { post: PostRow }) {
  const router = useRouter();
  const [title, setTitle] = useState(post.title);
  const [excerpt, setExcerpt] = useState(post.excerpt ?? "");
  const [bodyV, setBodyV] = useState(post.body ?? "");
  const [seoTitle, setSeoTitle] = useState(post.seo_title ?? "");
  const [seoDesc, setSeoDesc] = useState(post.seo_description ?? "");
  const [published, setPublished] = useState(post.published);

  const [pending, start] = useTransition();
  const [busy, startBusy] = useTransition();
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  function save() {
    const fd = new FormData();
    fd.set("slug", post.slug);
    fd.set("title", title);
    fd.set("excerpt", excerpt);
    fd.set("body", bodyV);
    fd.set("seo_title", seoTitle);
    fd.set("seo_description", seoDesc);
    start(async () => {
      const r = await updatePost(fd);
      setMsg(r.ok ? { ok: true, text: "Saved" } : { ok: false, text: r.error ?? "Failed" });
    });
  }
  function togglePublish() {
    const fd = new FormData();
    fd.set("slug", post.slug);
    fd.set("value", (!published).toString());
    startBusy(async () => {
      try { await togglePostPublished(fd); setPublished((v) => !v); }
      catch (e) { setMsg({ ok: false, text: e instanceof Error ? e.message : String(e) }); }
    });
  }
  function del() {
    if (!confirm(`Delete "${post.title}"? This can't be undone.`)) return;
    const fd = new FormData();
    fd.set("slug", post.slug);
    startBusy(async () => { await deletePost(fd); router.push("/admin/blog"); router.refresh(); });
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-3">
        <a href="/admin/blog" className="text-sm text-faint hover:text-ink">Back to Blog</a>
        <h1 className="text-xl font-semibold tracking-tight text-ink">Edit post</h1>
        <span className={"rounded-md px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider " +
          (published ? "border border-live/40 bg-live/10 text-live" : "border border-line text-faint")}>
          {published ? "Published" : "Draft"}
        </span>
        <code className="font-mono text-[11px] text-faint">/blog/{post.slug}</code>
        {published && (
          <a href={`/blog/${post.slug}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[11px] text-mute hover:text-gold">
            view <IconExternal size={11} />
          </a>
        )}
        <div className="ml-auto flex items-center gap-2">
          <button onClick={togglePublish} disabled={busy} className="rounded-md border border-line px-2.5 py-1 text-xs text-mute hover:text-ink disabled:opacity-40">
            {published ? "Unpublish" : "Publish"}
          </button>
          <button onClick={del} disabled={busy} className="inline-flex items-center gap-1 text-xs text-faint hover:text-bad disabled:opacity-40">
            <IconTrash size={14} /> Delete
          </button>
        </div>
      </div>

      <div className="space-y-3 rounded-xl border border-line bg-panel p-5">
        <label className="block">
          <span className={micro}>Title</span>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className={input} />
        </label>
        <label className="block">
          <span className={micro}>Excerpt</span>
          <input value={excerpt} onChange={(e) => setExcerpt(e.target.value)}
            placeholder="One-line summary for the list + search cards" className={input} />
        </label>

        <Cover post={post} />

        <label className="block">
          <span className={micro}>Body (Markdown)</span>
          <textarea rows={16} value={bodyV} onChange={(e) => setBodyV(e.target.value)} className={area} spellCheck={false} />
        </label>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <label className="block">
            <span className={micro}>SEO title (optional)</span>
            <input value={seoTitle} onChange={(e) => setSeoTitle(e.target.value)} placeholder="Defaults to the title" className={input} />
          </label>
          <label className="block">
            <span className={micro}>SEO description (optional)</span>
            <input value={seoDesc} onChange={(e) => setSeoDesc(e.target.value)} placeholder="Defaults to the excerpt" className={input} />
          </label>
        </div>

        <div className="flex items-center gap-3 pt-1">
          <button onClick={save} disabled={pending} className={saveBtn}>{pending ? "Saving…" : "Save"}</button>
          <Msg m={msg} />
        </div>
      </div>
    </div>
  );
}
