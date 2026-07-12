"use client";

import { useMemo, useState, useTransition } from "react";
import { createPage, deletePage, savePage, type Result } from "./actions";
import { Markdown } from "./markdown";
import { IconExternal, IconPlus, IconSearch, IconX } from "../_icons";

export type PageRow = { slug: string; title: string; body: string; updated_at: string };

const input =
  "w-full rounded-lg border border-line bg-panel2 px-3 py-2 text-[13px] text-ink outline-none placeholder:text-faint focus:border-teal";
const micro = "mb-1.5 block text-[10px] font-semibold uppercase tracking-wider text-faint";

function daysSince(iso: string) {
  return Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
}
function ago(iso: string) {
  const d = daysSince(iso);
  if (d <= 0) return "today";
  if (d === 1) return "1d";
  if (d < 365) return `${d}d`;
  return `${Math.floor(d / 365)}y`;
}

type Mode = "split" | "write" | "preview";

export function ContentClient({ pages }: { pages: PageRow[] }) {
  const [q, setQ] = useState("");
  const [slug, setSlug] = useState<string>(pages[0]?.slug ?? "");
  const [mode, setMode] = useState<Mode>("split");
  const [creating, setCreating] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [pending, start] = useTransition();

  // per-page working copy, so switching pages does not lose an edit
  const [draft, setDraft] = useState<Record<string, { title: string; body: string }>>({});

  const filtered = useMemo(() => {
    const n = q.trim().toLowerCase();
    if (!n) return pages;
    return pages.filter((p) => `${p.slug} ${p.title} ${p.body}`.toLowerCase().includes(n));
  }, [pages, q]);

  const page = pages.find((p) => p.slug === slug) ?? null;
  const d = page ? (draft[page.slug] ?? { title: page.title, body: page.body }) : null;
  const dirty = !!page && !!d && (d.title !== page.title || d.body !== page.body);

  const set = (k: "title" | "body", v: string) => {
    if (!page) return;
    setMsg(null);
    setDraft((s) => ({
      ...s,
      [page.slug]: { ...(s[page.slug] ?? { title: page.title, body: page.body }), [k]: v },
    }));
  };

  const run = (fd: FormData, fn: (f: FormData) => Promise<Result>, okText: string, after?: () => void) =>
    start(async () => {
      const r = await fn(fd);
      setMsg(r.ok ? { ok: true, text: okText } : { ok: false, text: r.error ?? "Failed" });
      if (r.ok) after?.();
    });

  function save() {
    if (!page || !d) return;
    const fd = new FormData();
    fd.set("slug", page.slug);
    fd.set("title", d.title);
    fd.set("body", d.body);
    run(fd, savePage, "Published", () =>
      setDraft((s) => {
        const n = { ...s };
        delete n[page.slug];
        return n;
      }),
    );
  }

  function remove() {
    if (!page) return;
    if (!confirm(`Delete /${page.slug}? The live page stops resolving immediately.`)) return;
    const fd = new FormData();
    fd.set("slug", page.slug);
    run(fd, deletePage, `Deleted /${page.slug}`, () => setSlug(pages.find((p) => p.slug !== page.slug)?.slug ?? ""));
  }

  return (
    <div className="grid gap-5 md:grid-cols-[236px_1fr] md:items-start">
      {/* pages */}
      <aside className="md:sticky md:top-5">
        <div className="relative mb-2">
          <span className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-faint">
            <IconSearch size={13} />
          </span>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search pages"
            className="w-full rounded-lg border border-line bg-panel2 py-1.5 pl-7 pr-2 text-[12.5px] text-ink outline-none placeholder:text-faint focus:border-line2"
          />
        </div>

        <div className="space-y-0.5">
          {filtered.map((p) => {
            const on = p.slug === slug;
            const stale = daysSince(p.updated_at) > 90;
            const edited = !!draft[p.slug];
            return (
              <button
                key={p.slug}
                onClick={() => {
                  setSlug(p.slug);
                  setCreating(false);
                  setMsg(null);
                }}
                className={
                  "flex w-full items-center gap-2.5 rounded-lg border-l-2 px-2.5 py-2 text-left " +
                  (on ? "border-l-teal bg-panel2" : "border-l-transparent hover:bg-panel")
                }
              >
                <span className={"h-1.5 w-1.5 flex-none rounded-full " + (stale ? "bg-warn" : "bg-live")} />
                <span className="min-w-0 flex-1">
                  <span className={"block text-[12.5px] font-medium " + (on ? "text-ink" : "text-mute")}>
                    {p.title}
                  </span>
                  <span className="mt-px block font-mono text-[10px] text-faint">/{p.slug}</span>
                </span>
                <span className="flex items-center gap-1.5 font-mono text-[10px] text-faint">
                  {ago(p.updated_at)}
                  {edited && <span className="h-1.5 w-1.5 rounded-full bg-gold" />}
                </span>
              </button>
            );
          })}
          {filtered.length === 0 && (
            <p className="px-2.5 py-6 text-center text-xs text-faint">No pages match.</p>
          )}
        </div>

        <button
          onClick={() => {
            setCreating(true);
            setMsg(null);
          }}
          className="mt-2 flex w-full items-center justify-center gap-1.5 rounded-lg border border-dashed border-line2 px-2.5 py-2 text-xs text-mute hover:border-teal hover:text-teal"
        >
          <IconPlus size={13} /> New page
        </button>
      </aside>

      {/* editor */}
      <div className="min-w-0">
        {creating ? (
          <NewPage
            pending={pending}
            msg={msg}
            onCancel={() => setCreating(false)}
            onCreate={(fd, next) =>
              run(fd, createPage, `Created /${next}`, () => {
                setCreating(false);
                setSlug(next);
              })
            }
          />
        ) : page && d ? (
          <div className="overflow-hidden rounded-xl border border-line bg-panel">
            <div className="flex items-center gap-2.5 border-b border-line bg-raise px-3.5 py-2.5">
              <div className="flex rounded-lg border border-line bg-panel p-0.5">
                {(["split", "write", "preview"] as Mode[]).map((m) => (
                  <button
                    key={m}
                    onClick={() => setMode(m)}
                    className={
                      "rounded-md px-2.5 py-1 text-[11.5px] capitalize " +
                      (mode === m ? "bg-panel2 text-ink" : "text-mute hover:text-ink")
                    }
                  >
                    {m}
                  </button>
                ))}
              </div>
              <code className="font-mono text-[11px] text-faint">/{page.slug}</code>
              <span className="flex-1" />
              <a
                href={`/${page.slug}`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 text-[11.5px] text-mute hover:text-teal"
              >
                view live <IconExternal size={11} />
              </a>
            </div>

            <div className={"grid " + (mode === "split" ? "md:grid-cols-2" : "grid-cols-1")}>
              {mode !== "preview" && (
                <div className="p-3.5">
                  <span className={micro}>Title</span>
                  <input
                    value={d.title}
                    onChange={(e) => set("title", e.target.value)}
                    className={input + " mb-3 text-[14px] font-semibold"}
                  />
                  <span className={micro}>Markdown</span>
                  <textarea
                    value={d.body}
                    onChange={(e) => set("body", e.target.value)}
                    spellCheck={false}
                    rows={18}
                    className="w-full resize-none rounded-lg border border-line bg-bg p-3 font-mono text-[12.5px] leading-relaxed text-ink outline-none focus:border-teal"
                  />
                </div>
              )}

              {mode !== "write" && (
                <div className={"p-3.5 " + (mode === "split" ? "border-line md:border-l" : "")}>
                  <span className={micro}>Preview, as fructa.africa renders it</span>
                  <div className="h-[458px] overflow-auto rounded-lg border border-line bg-bg px-4 py-4">
                    <Markdown source={d.body} />
                  </div>
                </div>
              )}
            </div>

            <div className="flex flex-wrap items-center gap-3 border-t border-line bg-raise px-3.5 py-2.5">
              <span className="text-[11.5px] text-faint">
                Published {new Date(page.updated_at).toLocaleString()}. Saving publishes to fructa.africa/{page.slug}.
              </span>
              <span className="flex-1" />
              {msg && (
                <span className={"text-[11.5px] " + (msg.ok ? "text-live" : "text-bad")}>{msg.text}</span>
              )}
              {dirty && <span className="text-[11.5px] text-gold">Unsaved changes</span>}
              <button
                onClick={remove}
                disabled={pending}
                className="rounded-lg border border-line2 px-2.5 py-1.5 text-[11.5px] text-faint hover:border-bad hover:text-bad disabled:opacity-40"
              >
                Delete
              </button>
              <button
                onClick={() =>
                  setDraft((s) => {
                    const n = { ...s };
                    delete n[page.slug];
                    return n;
                  })
                }
                disabled={!dirty || pending}
                className="rounded-lg border border-line2 px-2.5 py-1.5 text-[11.5px] text-mute hover:text-ink disabled:opacity-40"
              >
                Discard
              </button>
              <button
                onClick={save}
                disabled={!dirty || pending}
                className="rounded-lg border border-teal bg-teal/15 px-3 py-1.5 text-[12px] font-semibold text-teal hover:bg-teal/25 disabled:opacity-40"
              >
                {pending ? "Publishing" : "Save and publish"}
              </button>
            </div>
          </div>
        ) : (
          <p className="rounded-xl border border-line bg-panel px-4 py-12 text-center text-sm text-mute">
            No pages yet. Create the first one.
          </p>
        )}
      </div>
    </div>
  );
}

function NewPage({
  pending,
  msg,
  onCancel,
  onCreate,
}: {
  pending: boolean;
  msg: { ok: boolean; text: string } | null;
  onCancel: () => void;
  onCreate: (fd: FormData, slug: string) => void;
}) {
  const [title, setTitle] = useState("");
  const [slug, setSlug] = useState("");
  const [touched, setTouched] = useState(false);

  // slug follows the title until you edit it yourself
  const effective = touched
    ? slug
    : title
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, "")
        .trim()
        .replace(/\s+/g, "-");

  return (
    <div className="overflow-hidden rounded-xl border border-line bg-panel">
      <div className="flex items-center gap-2 border-b border-line bg-raise px-3.5 py-2.5">
        <span className="text-[12.5px] font-semibold text-ink">New page</span>
        <span className="flex-1" />
        <button onClick={onCancel} className="text-faint hover:text-ink" aria-label="Cancel">
          <IconX size={13} />
        </button>
      </div>
      <div className="space-y-3 p-4">
        <div>
          <span className={micro}>Title</span>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Cookie Policy" className={input} />
        </div>
        <div>
          <span className={micro}>Address</span>
          <div className="flex items-center gap-2">
            <span className="font-mono text-[12.5px] text-faint">fructa.africa/</span>
            <input
              value={effective}
              onChange={(e) => {
                setTouched(true);
                setSlug(e.target.value);
              }}
              placeholder="cookie-policy"
              className={input + " font-mono"}
            />
          </div>
        </div>
        {msg && !msg.ok && <p className="text-xs text-bad">{msg.text}</p>}
      </div>
      <div className="flex items-center gap-3 border-t border-line bg-raise px-3.5 py-2.5">
        <span className="flex-1 text-[11.5px] text-faint">
          The page is created with a heading, ready to write.
        </span>
        <button onClick={onCancel} className="rounded-lg border border-line2 px-2.5 py-1.5 text-[11.5px] text-mute hover:text-ink">
          Cancel
        </button>
        <button
          onClick={() => {
            const fd = new FormData();
            fd.set("title", title);
            fd.set("slug", effective);
            fd.set("body", "");
            onCreate(fd, effective);
          }}
          disabled={pending || !title.trim() || !effective}
          className="rounded-lg border border-teal bg-teal/15 px-3 py-1.5 text-[12px] font-semibold text-teal hover:bg-teal/25 disabled:opacity-40"
        >
          {pending ? "Creating" : "Create page"}
        </button>
      </div>
    </div>
  );
}
