"use client";

import { useState, useTransition } from "react";
import { savePage, type Result } from "./actions";
import { IconCheck, IconExternal } from "../_icons";

export type PageRow = { slug: string; title: string; body: string; updated_at: string };

const input =
  "w-full rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60";
const area = input + " font-mono text-[13px] leading-relaxed";
const micro = "mb-1 block text-[10px] uppercase tracking-wider text-faint";
const saveBtn =
  "rounded-md border border-gold/50 bg-gold/10 px-3 py-1.5 text-xs font-medium text-gold hover:bg-gold/20 disabled:opacity-40";

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
  const run = (fd: FormData, fn: (f: FormData) => Promise<Result>, okText: string) =>
    start(async () => {
      const r = await fn(fd);
      setMsg(r.ok ? { ok: true, text: okText } : { ok: false, text: r.error ?? "Failed" });
    });
  return { pending, msg, run };
}

function PageEditor({ page }: { page: PageRow }) {
  const [title, setTitle] = useState(page.title);
  const [bodyV, setBodyV] = useState(page.body);
  const { pending, msg, run } = useSaver();

  function save() {
    const fd = new FormData();
    fd.set("slug", page.slug);
    fd.set("title", title);
    fd.set("body", bodyV);
    run(fd, savePage, "Saved");
  }

  return (
    <div className="rounded-xl border border-line bg-panel p-4">
      <div className="mb-3 flex items-center justify-between">
        <code className="font-mono text-[11px] text-faint">/{page.slug}</code>
        <a href={`/${page.slug}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[11px] text-mute hover:text-gold">
          view <IconExternal size={11} />
        </a>
      </div>
      <label className="mb-3 block">
        <span className={micro}>Title</span>
        <input value={title} onChange={(e) => setTitle(e.target.value)} className={input} />
      </label>
      <label className="block">
        <span className={micro}>Body (Markdown)</span>
        <textarea rows={12} value={bodyV} onChange={(e) => setBodyV(e.target.value)} className={area} spellCheck={false} />
      </label>
      <div className="mt-3 flex items-center gap-3">
        <button onClick={save} disabled={pending} className={saveBtn}>Save &amp; publish</button>
        <Msg m={msg} />
      </div>
    </div>
  );
}

export function ContentClient({ pages }: { pages: PageRow[] }) {
  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2">
        <span className="text-[11px] uppercase tracking-wider text-gold">Pages</span>
        <span className="tnum text-[11px] text-faint">{pages.length}</span>
        <div className="h-px flex-1 bg-line" />
      </div>
      {pages.map((p) => (
        <PageEditor key={p.slug} page={p} />
      ))}
      {pages.length === 0 && (
        <p className="rounded-xl border border-line bg-panel px-4 py-8 text-center text-sm text-mute">
          No pages yet.
        </p>
      )}
    </div>
  );
}
