"use client";

import { useMemo, useRef, useState, useTransition } from "react";
import {
  createPost, updatePost, togglePostPublished, deletePost,
  uploadPostCover, removePostCover, type Result,
} from "./actions";
import {
  IconArticle, IconBolt, IconPin, IconCheck, IconExternal, IconSearch,
  IconPlus, IconX, IconClock, IconTrash,
} from "../_icons";

export type PostRow = {
  slug: string;
  kind: "article" | "brief";
  title: string;
  excerpt: string | null;
  body: string;
  cover_url: string | null;
  published: boolean;
  published_at: string | null;
  seo_title: string | null;
  seo_description: string | null;
  tags: string[];
  fund_id: string | null;
  company_id: string | null;
  pinned: boolean;
  reading_minutes: number | null;
  updated_at: string;
};

export type LinkOption = { type: "fund" | "company"; id: string; name: string };

const input =
  "w-full rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60";
const area = input + " font-mono text-[13px] leading-relaxed";
const micro = "mb-1.5 block text-[10px] uppercase tracking-wider text-faint";
const goldBtn =
  "rounded-md border border-gold/50 bg-gold/10 px-3.5 py-1.5 text-xs font-medium text-gold hover:bg-gold/20 disabled:opacity-40";
const ghostBtn =
  "rounded-md border border-line px-3 py-1.5 text-xs text-mute hover:text-ink disabled:opacity-40";

function ago(iso: string): string {
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 90) return "just now";
  if (s < 3600) return `${Math.round(s / 60)}m`;
  if (s < 86400) return `${Math.round(s / 3600)}h`;
  return `${Math.round(s / 86400)}d`;
}

function readingFor(body: string): number {
  const words = body.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.round(words / 200));
}

function Msg({ m }: { m: { ok: boolean; text: string } | null }) {
  if (!m) return null;
  return (
    <span className={"inline-flex items-center gap-1 text-[11px] " + (m.ok ? "text-live" : "text-bad")}>
      {m.ok && <IconCheck size={11} />}
      {m.text}
    </span>
  );
}

function useSaver() {
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const run = (fd: FormData, fn: (f: FormData) => Promise<Result>, okText: string, after?: () => void) =>
    start(async () => {
      const r = await fn(fd);
      setMsg(r.ok ? { ok: true, text: okText } : { ok: false, text: r.error ?? "Failed" });
      if (r.ok) after?.();
    });
  return { pending, msg, setMsg, run };
}

// ── Tag chips ────────────────────────────────────────────────────────────────
function Tags({ value, onChange }: { value: string[]; onChange: (t: string[]) => void }) {
  const [draft, setDraft] = useState("");
  function commit() {
    const t = draft.trim().toLowerCase();
    if (t && !value.includes(t)) onChange([...value, t].slice(0, 12));
    setDraft("");
  }
  return (
    <div className="flex flex-wrap items-center gap-1.5 rounded-md border border-line bg-panel2 px-2 py-1.5">
      {value.map((t) => (
        <span key={t} className="inline-flex items-center gap-1 rounded bg-gold/10 px-2 py-0.5 text-[11px] text-gold">
          {t}
          <button type="button" onClick={() => onChange(value.filter((x) => x !== t))} aria-label={`Remove ${t}`}>
            <IconX size={11} />
          </button>
        </span>
      ))}
      <input
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === ",") { e.preventDefault(); commit(); }
          if (e.key === "Backspace" && !draft && value.length) onChange(value.slice(0, -1));
        }}
        onBlur={commit}
        placeholder="add"
        className="min-w-[52px] flex-1 bg-transparent text-[12px] text-ink outline-none placeholder:text-faint"
      />
    </div>
  );
}

// ── Link picker (fund xor company) ──────────────────────────────────────────
function LinkPicker({
  links, fundId, companyId, onChange,
}: {
  links: LinkOption[];
  fundId: string | null;
  companyId: string | null;
  onChange: (fund: string | null, company: string | null) => void;
}) {
  const value = fundId ? `fund:${fundId}` : companyId ? `company:${companyId}` : "";
  const funds = links.filter((l) => l.type === "fund");
  const companies = links.filter((l) => l.type === "company");
  return (
    <select
      value={value}
      onChange={(e) => {
        const v = e.target.value;
        if (!v) return onChange(null, null);
        const [type, id] = v.split(":");
        type === "fund" ? onChange(id, null) : onChange(null, id);
      }}
      className={input + " appearance-none"}
    >
      <option value="">No link</option>
      <optgroup label="Funds">
        {funds.map((f) => <option key={f.id} value={`fund:${f.id}`}>{f.name}</option>)}
      </optgroup>
      <optgroup label="Companies">
        {companies.map((c) => <option key={c.id} value={`company:${c.id}`}>{c.name}</option>)}
      </optgroup>
    </select>
  );
}

// ── Cover (articles only) ────────────────────────────────────────────────────
function Cover({ post }: { post: PostRow }) {
  const [preview, setPreview] = useState<string | null>(null);
  const { pending, msg, run, setMsg } = useSaver();
  const fileRef = useRef<HTMLInputElement>(null);

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
    <div>
      <span className={micro}>Cover</span>
      <div className="overflow-hidden rounded-md border border-line bg-panel2" style={{ aspectRatio: "16 / 8" }}>
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
      <form action={upload} className="mt-2 flex items-center gap-2">
        <input
          ref={fileRef}
          type="file"
          name="file"
          accept="image/png,image/webp,image/jpeg"
          required
          onChange={pick}
          className="w-full text-[11px] text-faint file:mr-2 file:rounded file:border file:border-line file:bg-panel2 file:px-2 file:py-1 file:text-[11px] file:text-mute"
        />
        <button disabled={pending} className={goldBtn}>{pending ? "…" : "Upload"}</button>
      </form>
      <div className="mt-1 flex items-center gap-3">
        <Msg m={msg} />
        {post.cover_url && (
          <button onClick={remove} disabled={pending} className="text-[11px] text-faint hover:text-bad disabled:opacity-40">
            Remove
          </button>
        )}
      </div>
    </div>
  );
}

// ── App preview ──────────────────────────────────────────────────────────────
function AppPreview({ kind, title, summary, reading }: { kind: "article" | "brief"; title: string; summary: string; reading: number }) {
  return (
    <div>
      <span className={micro}>In the app</span>
      <div className="rounded-lg border border-line bg-bg p-3">
        <div className="mb-1.5 flex items-center gap-1.5">
          <span className="h-1.5 w-1.5 rounded-full bg-gold" />
          <span className="text-[9px] uppercase tracking-wider text-gold">
            {kind === "article" ? `Article · ${reading} min` : "Brief"}
          </span>
        </div>
        <div className="text-[12px] leading-snug text-ink">{title || "Untitled"}</div>
        {summary && <div className="mt-1 text-[10.5px] leading-snug text-mute">{summary}</div>}
      </div>
    </div>
  );
}

// ── Editor ───────────────────────────────────────────────────────────────────
function Editor({ post, links }: { post: PostRow; links: LinkOption[] }) {
  const [kind, setKind] = useState<"article" | "brief">(post.kind);
  const [title, setTitle] = useState(post.title);
  const [excerpt, setExcerpt] = useState(post.excerpt ?? "");
  const [bodyV, setBodyV] = useState(post.body ?? "");
  const [tags, setTags] = useState<string[]>(post.tags ?? []);
  const [fundId, setFundId] = useState(post.fund_id);
  const [companyId, setCompanyId] = useState(post.company_id);
  const [pinned, setPinned] = useState(post.pinned);
  const [readOverride, setReadOverride] = useState<string>(post.reading_minutes != null ? String(post.reading_minutes) : "");
  const [seoTitle, setSeoTitle] = useState(post.seo_title ?? "");
  const [seoDesc, setSeoDesc] = useState(post.seo_description ?? "");
  const [seoOpen, setSeoOpen] = useState(false);

  const { pending, msg, run } = useSaver();
  const [busy, start] = useTransition();

  const readingAuto = useMemo(() => readingFor(bodyV), [bodyV]);
  const reading = readOverride ? Math.max(1, Math.round(Number(readOverride))) : readingAuto;

  function save() {
    const fd = new FormData();
    fd.set("slug", post.slug);
    fd.set("kind", kind);
    fd.set("title", title);
    fd.set("excerpt", excerpt);
    fd.set("body", bodyV);
    fd.set("tags", JSON.stringify(tags));
    fd.set("fund_id", fundId ?? "");
    fd.set("company_id", companyId ?? "");
    if (kind === "article") {
      fd.set("pinned", pinned ? "true" : "false");
      fd.set("reading_minutes", readOverride || String(readingAuto));
      fd.set("seo_title", seoTitle);
      fd.set("seo_description", seoDesc);
    }
    run(fd, updatePost, "Saved");
  }
  function togglePublish() {
    const fd = new FormData();
    fd.set("slug", post.slug);
    fd.set("value", (!post.published).toString());
    start(() => { void togglePostPublished(fd); });
  }
  function del() {
    if (!confirm(`Delete "${post.title}"? This can't be undone.`)) return;
    const fd = new FormData();
    fd.set("slug", post.slug);
    start(() => { void deletePost(fd); });
  }

  const isArticle = kind === "article";

  return (
    <div className="flex flex-1 flex-col">
      {/* toolbar */}
      <div className="flex items-center gap-2.5 border-b border-line px-4 py-3">
        <div className="inline-flex rounded-md border border-line bg-panel2 p-0.5">
          {(["article", "brief"] as const).map((k) => (
            <button
              key={k}
              onClick={() => setKind(k)}
              className={"rounded px-3 py-1 text-xs capitalize " + (kind === k ? "bg-panel text-ink" : "text-mute")}
            >
              {k}
            </button>
          ))}
        </div>
        <span
          className={
            "rounded px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider " +
            (post.published ? "border border-live/40 text-live" : "border border-line text-faint")
          }
        >
          {post.published ? "Published" : "Draft"}
        </span>
        <div className="ml-auto flex items-center gap-2">
          <button onClick={save} disabled={pending} className={goldBtn}>Save</button>
          <button onClick={togglePublish} disabled={busy} className={ghostBtn}>
            {post.published ? "Unpublish" : "Publish"}
          </button>
          <button onClick={del} disabled={busy} className="inline-flex items-center gap-1 text-[11px] text-faint hover:text-bad disabled:opacity-40">
            <IconTrash size={13} />
          </button>
        </div>
      </div>

      {/* body + meta */}
      <div className="flex flex-1">
        <div className="min-w-0 flex-1 border-r border-line p-5">
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Title"
            className="w-full bg-transparent text-[21px] font-medium tracking-tight text-ink outline-none placeholder:text-faint"
          />
          <div className="mb-4 mt-2 flex flex-wrap items-center gap-3">
            <code className="font-mono text-[11px] text-faint">/blog/{post.slug}</code>
            {isArticle && (
              <button
                onClick={() => setPinned((v) => !v)}
                className={"inline-flex items-center gap-1 text-[11px] " + (pinned ? "text-gold" : "text-faint hover:text-mute")}
              >
                <IconPin size={13} /> {pinned ? "Pinned" : "Pin"}
              </button>
            )}
            {post.published && (
              <a href={`/blog/${post.slug}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[11px] text-mute hover:text-gold">
                view <IconExternal size={11} />
              </a>
            )}
          </div>

          <label className="mb-4 block">
            <span className={micro}>Summary</span>
            <input
              value={excerpt}
              onChange={(e) => setExcerpt(e.target.value)}
              placeholder="One line — used on the website list and the app briefs rail"
              className={input}
            />
          </label>

          <label className="block">
            <span className={micro}>Body</span>
            <textarea
              rows={isArticle ? 14 : 6}
              value={bodyV}
              onChange={(e) => setBodyV(e.target.value)}
              spellCheck={false}
              className={area}
            />
          </label>

          {isArticle && (
            <div className="mt-4">
              <button onClick={() => setSeoOpen((v) => !v)} className="text-[11px] uppercase tracking-wider text-faint hover:text-mute">
                SEO {seoOpen ? "−" : "+"}
              </button>
              {seoOpen && (
                <div className="mt-2 grid grid-cols-2 gap-3">
                  <label className="block">
                    <span className={micro}>SEO title</span>
                    <input value={seoTitle} onChange={(e) => setSeoTitle(e.target.value)} placeholder="Defaults to the title" className={input} />
                  </label>
                  <label className="block">
                    <span className={micro}>SEO description</span>
                    <input value={seoDesc} onChange={(e) => setSeoDesc(e.target.value)} placeholder="Defaults to the summary" className={input} />
                  </label>
                </div>
              )}
            </div>
          )}
        </div>

        {/* meta rail */}
        <div className="flex w-[240px] flex-col gap-4 p-4">
          <div>
            <span className={micro}>Tags</span>
            <Tags value={tags} onChange={setTags} />
          </div>

          <div>
            <span className={micro}>Link fund or company</span>
            <LinkPicker
              links={links}
              fundId={fundId}
              companyId={companyId}
              onChange={(f, c) => { setFundId(f); setCompanyId(c); }}
            />
          </div>

          {isArticle && (
            <>
              <Cover post={post} />
              <div>
                <span className={micro}>Reading time</span>
                <div className="flex items-center gap-2">
                  <div className="inline-flex items-center gap-1.5 text-[13px] text-ink">
                    <IconClock size={13} /> {reading} min
                  </div>
                  <input
                    value={readOverride}
                    onChange={(e) => setReadOverride(e.target.value.replace(/[^0-9]/g, ""))}
                    placeholder={`${readingAuto} auto`}
                    className={input + " ml-auto w-20 text-center"}
                  />
                </div>
              </div>
            </>
          )}

          <div className="mt-auto">
            <AppPreview kind={kind} title={title} summary={excerpt} reading={reading} />
          </div>
        </div>
      </div>

      {/* footer */}
      <div className="flex items-center gap-2 border-t border-line px-5 py-2.5">
        <Msg m={msg} />
        <span className="text-[11px] text-faint">edited {ago(post.updated_at)} ago</span>
      </div>
    </div>
  );
}

// ── New-post inline creator ──────────────────────────────────────────────────
function Creator({ kind, onDone }: { kind: "article" | "brief"; onDone: (slug?: string) => void }) {
  const [title, setTitle] = useState("");
  const { pending, msg, run } = useSaver();
  function create() {
    const fd = new FormData();
    fd.set("title", title);
    fd.set("kind", kind);
    // createPost returns a slug; useSaver's Result type is compatible via structural typing
    run(fd, createPost as unknown as (f: FormData) => Promise<Result>, "Created", () => onDone());
  }
  return (
    <div className="border-b border-line bg-panel2 p-3">
      <span className={micro}>New {kind}</span>
      <input
        autoFocus
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter") create(); if (e.key === "Escape") onDone(); }}
        placeholder={kind === "article" ? "Understanding net vs gross yield" : "CBK holds the rate at…"}
        className={input}
      />
      <div className="mt-2 flex items-center gap-2">
        <button onClick={create} disabled={pending} className={goldBtn}>Create</button>
        <button onClick={() => onDone()} className={ghostBtn}>Cancel</button>
        <Msg m={msg} />
      </div>
    </div>
  );
}

// ── Root ─────────────────────────────────────────────────────────────────────
export function BlogClient({ posts, links }: { posts: PostRow[]; links: LinkOption[] }) {
  const [filter, setFilter] = useState<"all" | "article" | "brief">("all");
  const [q, setQ] = useState("");
  const [sel, setSel] = useState<string | null>(posts[0]?.slug ?? null);
  const [creating, setCreating] = useState<"article" | "brief" | null>(null);

  const list = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return posts.filter(
      (p) =>
        (filter === "all" || p.kind === filter) &&
        (!needle || p.title.toLowerCase().includes(needle) || (p.excerpt ?? "").toLowerCase().includes(needle)),
    );
  }, [posts, filter, q]);

  const selected = posts.find((p) => p.slug === sel) ?? null;

  return (
    <div className="flex min-h-[560px] overflow-hidden rounded-xl border border-line bg-panel">
      {/* list */}
      <aside className="flex w-[248px] flex-col border-r border-line bg-panel2/40">
        <div className="p-3">
          <div className="flex gap-3 border-b border-line pb-2 text-xs">
            {(["all", "article", "brief"] as const).map((k) => (
              <button
                key={k}
                onClick={() => setFilter(k)}
                className={"pb-2 capitalize " + (filter === k ? "-mb-[9px] border-b-[1.5px] border-gold text-ink" : "text-mute")}
              >
                {k === "all" ? "All" : k + "s"}
              </button>
            ))}
          </div>
          <div className="mt-3 flex items-center gap-2 text-faint">
            <IconSearch size={14} />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search posts"
              className="w-full bg-transparent text-xs text-ink outline-none placeholder:text-faint"
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {creating && <Creator kind={creating} onDone={(slug) => { setCreating(null); if (slug) setSel(slug); }} />}
          {list.map((p) => (
            <button
              key={p.slug}
              onClick={() => setSel(p.slug)}
              className={
                "flex w-full gap-2.5 px-3.5 py-3 text-left " +
                (p.slug === sel ? "border-l-2 border-gold bg-panel" : "border-l-2 border-transparent hover:bg-panel/50")
              }
            >
              <span
                className={"mt-1.5 h-1.5 w-1.5 flex-none rounded-full " + (p.published ? "bg-live" : "bg-gold")}
                title={p.published ? "Published" : "Draft"}
              />
              <span className="min-w-0">
                <span className="block text-[12.5px] leading-snug text-ink">{p.title}</span>
                <span className="mt-1 block text-[10px] text-faint">
                  {p.kind === "article" ? "Article" : "Brief"}
                  {p.tags.length ? " · " + p.tags.slice(0, 2).join(", ") : ""} · {ago(p.updated_at)}
                </span>
              </span>
            </button>
          ))}
          {list.length === 0 && !creating && (
            <p className="px-4 py-8 text-center text-xs text-mute">No posts match.</p>
          )}
        </div>

        <div className="flex gap-2 border-t border-line p-3">
          <button onClick={() => setCreating("article")} className={"flex-1 inline-flex items-center justify-center gap-1.5 " + goldBtn}>
            <IconPlus size={13} /> Article
          </button>
          <button onClick={() => setCreating("brief")} className={"flex-1 inline-flex items-center justify-center gap-1.5 " + ghostBtn}>
            <IconBolt size={13} /> Brief
          </button>
        </div>
      </aside>

      {/* editor */}
      {selected ? (
        <Editor key={selected.slug} post={selected} links={links} />
      ) : (
        <div className="flex flex-1 flex-col items-center justify-center gap-3 text-mute">
          <IconArticle size={26} />
          <p className="text-sm">Select a post, or start a new one.</p>
        </div>
      )}
    </div>
  );
}
