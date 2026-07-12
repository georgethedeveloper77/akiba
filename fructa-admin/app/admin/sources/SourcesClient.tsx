"use client";

import { useMemo, useState, useTransition } from "react";
import { setRate, setSourceType } from "../funds/actions";
import { updateSourceLinks, type Result } from "./actions";
import { IconExternal, IconSearch, IconX } from "../_icons";

export type Lane = "scraped" | "manual" | "imported" | "consensus";

export type Src = {
  id: string;
  name: string;
  manager: string;
  category: string;
  current_rate: number | null;
  updated_at: string;
  status: string;
  source_type: "auto" | "manual";
  rate_source_url: string | null;
  site_url: string | null;
  lane: Lane;
  lastSource: string | null;
  spark: number[];
};

const CATS: Record<string, string> = {
  mmf_kes: "MMF KES",
  mmf_usd: "MMF USD",
  tbill: "T-Bills",
  bond: "Bonds",
  sacco: "SACCO",
  stock: "NSE",
};

const STALE_DAYS = 7;
const WARN_DAYS = 5;

const LANE_CLS: Record<Lane, string> = {
  scraped: "bg-live/10 text-live",
  manual: "bg-gold/10 text-gold",
  imported: "bg-blue/10 text-blue",
  consensus: "bg-violet/10 text-violet",
};

function daysSince(iso: string) {
  return Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
}
function ago(iso: string) {
  const d = daysSince(iso);
  if (d <= 0) return "today";
  return `${d}d old`;
}

/** A rate is your problem when nobody else will fix it, or when the robot stopped. */
function needsYou(r: Src) {
  return r.lane === "manual" || r.status === "stale" || daysSince(r.updated_at) >= STALE_DAYS;
}

function Spark({ points, tone }: { points: number[]; tone: string }) {
  if (points.length < 2) {
    return <span className="font-mono text-[10.5px] text-faint">no history</span>;
  }
  const min = Math.min(...points);
  const max = Math.max(...points);
  const span = max - min || 1;
  const d = points
    .map((p, i) => `${(i / (points.length - 1)) * 100},${22 - ((p - min) / span) * 18 - 2}`)
    .join(" ");
  return (
    <svg viewBox="0 0 100 22" preserveAspectRatio="none" className="h-[22px] w-full">
      <polyline points={d} fill="none" stroke="currentColor" strokeWidth={1.5} className={tone} />
    </svg>
  );
}

export function SourcesClient({ rows }: { rows: Src[] }) {
  const [q, setQ] = useState("");
  const [lane, setLane] = useState<Lane | "all">("all");
  const [editing, setEditing] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [pending, start] = useTransition();

  const filtered = useMemo(() => {
    const n = q.trim().toLowerCase();
    return rows.filter((r) => {
      if (lane !== "all" && r.lane !== lane) return false;
      if (n && !`${r.name} ${r.manager} ${r.category} ${r.lastSource ?? ""}`.toLowerCase().includes(n)) return false;
      return true;
    });
  }, [rows, q, lane]);

  const queue = useMemo(
    () =>
      filtered
        .filter(needsYou)
        .sort((a, b) => daysSince(b.updated_at) - daysSince(a.updated_at)),
    [filtered],
  );
  const healthy = useMemo(
    () =>
      filtered
        .filter((r) => !needsYou(r))
        .sort((a, b) => (b.current_rate ?? 0) - (a.current_rate ?? 0)),
    [filtered],
  );

  const laneCount = (l: Lane) => rows.filter((r) => r.lane === l).length;

  const Chip = ({ id, label, n }: { id: Lane | "all"; label: string; n: number }) => (
    <button
      onClick={() => setLane(id)}
      className={
        "inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1 text-[11.5px] " +
        (lane === id ? "border-line2 bg-panel2 text-ink" : "border-line text-faint hover:text-ink")
      }
    >
      {id !== "all" && <span className={"h-1.5 w-1.5 rounded-full " + LANE_CLS[id].split(" ")[0].replace("/10", "")} />}
      {label} <span className="tnum text-faint">{n}</span>
    </button>
  );

  function saveLinks(fd: FormData, id: string) {
    start(async () => {
      const r: Result = await updateSourceLinks(fd);
      setMsg(r.ok ? { ok: true, text: "Links saved" } : { ok: false, text: r.error ?? "Failed" });
      if (r.ok) setEditing(null);
    });
  }

  return (
    <div className="space-y-6">
      {/* search + filters */}
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[240px] flex-1">
          <span className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-faint">
            <IconSearch size={14} />
          </span>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search fund, manager or adapter"
            className="w-full rounded-lg border border-line bg-panel2 py-2 pl-8 pr-3 text-[13px] text-ink outline-none placeholder:text-faint focus:border-gold/60"
          />
        </div>
        <Chip id="all" label="All" n={rows.length} />
        <Chip id="manual" label="Manual" n={laneCount("manual")} />
        <Chip id="scraped" label="Scraped" n={laneCount("scraped")} />
        <Chip id="imported" label="Imported" n={laneCount("imported")} />
        <Chip id="consensus" label="Consensus" n={laneCount("consensus")} />
        {msg && (
          <span className={"text-[11.5px] " + (msg.ok ? "text-live" : "text-bad")}>{msg.text}</span>
        )}
      </div>

      {/* the queue: the actual job */}
      {queue.length > 0 && (
        <div className="overflow-hidden rounded-xl border border-warn/30 bg-warn/[0.035]">
          <div className="flex items-center gap-2.5 border-b border-line px-4 py-3">
            <span className="h-1.5 w-1.5 rounded-full bg-warn" />
            <span className="text-[12.5px] font-semibold text-warn">{queue.length} need a look</span>
            <span className="text-[11.5px] text-faint">
              Manual sources, and anything that has gone quiet for {STALE_DAYS} days or more
            </span>
          </div>

          {queue.map((r) => {
            const days = daysSince(r.updated_at);
            const tone = days >= STALE_DAYS ? "text-bad" : days >= WARN_DAYS ? "text-warn" : "text-faint";
            const url = r.rate_source_url ?? r.site_url;
            return (
              <div key={r.id} className="border-b border-line last:border-0">
                <div className="grid items-center gap-3 px-4 py-3 md:grid-cols-[1fr_92px_88px_auto_auto]">
                  <div className="min-w-0">
                    <div className="text-[13px] font-medium text-ink">{r.name}</div>
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-[11px] text-faint">
                      <span className={"rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold uppercase " + LANE_CLS[r.lane]}>
                        {r.lane}
                      </span>
                      {CATS[r.category] ?? r.category} · {r.manager}
                    </div>
                  </div>

                  <div className="text-right">
                    <div className="font-mono text-[15px] font-semibold tnum text-ink">
                      {r.current_rate != null ? `${Number(r.current_rate).toFixed(2)}%` : "none"}
                    </div>
                    <div className={"font-mono text-[11px] " + tone}>{ago(r.updated_at)}</div>
                  </div>

                  <div className={days >= STALE_DAYS ? "text-bad" : "text-live"}>
                    <Spark points={r.spark} tone={days >= STALE_DAYS ? "text-bad" : "text-live"} />
                  </div>

                  <div className="flex items-center gap-2">
                    {url ? (
                      <a
                        href={url}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1.5 rounded-lg border border-line px-2.5 py-1.5 text-[12px] text-mute hover:border-gold hover:text-gold"
                      >
                        Open source <IconExternal size={11} />
                      </a>
                    ) : (
                      <button
                        onClick={() => setEditing(r.id)}
                        className="rounded-lg border border-dashed border-line2 px-2.5 py-1.5 text-[12px] text-faint hover:border-gold hover:text-gold"
                      >
                        Add a link
                      </button>
                    )}
                    <button
                      onClick={() => setEditing(editing === r.id ? null : r.id)}
                      className="rounded-lg border border-line px-2 py-1.5 text-[11.5px] text-faint hover:text-ink"
                    >
                      Edit
                    </button>
                  </div>

                  <form action={setRate} className="flex items-center gap-1.5">
                    <input type="hidden" name="id" value={r.id} />
                    <input
                      name="rate"
                      type="number"
                      step="0.01"
                      min="0"
                      max="30"
                      placeholder={r.current_rate != null ? Number(r.current_rate).toFixed(2) : "0.00"}
                      className="w-[74px] rounded-lg border border-line bg-panel2 px-2 py-1.5 text-right font-mono text-[13px] tnum text-ink outline-none focus:border-gold"
                    />
                    <button className="rounded-lg border border-gold bg-gold px-2.5 py-1.5 text-[12px] font-semibold text-[#191204] hover:brightness-110">
                      Set
                    </button>
                  </form>
                </div>

                {editing === r.id && (
                  <LinkEditor row={r} pending={pending} onCancel={() => setEditing(null)} onSave={saveLinks} />
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* healthy */}
      <div>
        <div className="mb-2.5 flex items-center gap-2.5">
          <span className="text-[10px] font-bold uppercase tracking-widest text-live">Healthy</span>
          <span className="text-[11.5px] text-faint">
            {healthy.length} arriving on schedule. Nothing to do here.
          </span>
          <span className="h-px flex-1 bg-line" />
        </div>

        <div className="overflow-hidden rounded-xl border border-line bg-panel">
          <table className="w-full">
            <thead>
              <tr className="bg-raise text-left text-[10px] uppercase tracking-wider text-faint">
                <th className="px-4 py-2.5 font-semibold">Fund</th>
                <th className="px-3 py-2.5 font-semibold">Lane</th>
                <th className="px-3 py-2.5 text-right font-semibold">Rate</th>
                <th className="px-3 py-2.5 font-semibold">Trend</th>
                <th className="px-3 py-2.5 font-semibold">Last seen</th>
                <th className="px-3 py-2.5 font-semibold">Adapter</th>
                <th className="px-3 py-2.5 font-semibold">Source</th>
                <th className="px-3 py-2.5" />
              </tr>
            </thead>
            <tbody>
              {healthy.map((r) => {
                const url = r.rate_source_url ?? r.site_url;
                return (
                  <tr key={r.id} className="border-t border-line hover:bg-raise">
                    <td className="px-4 py-2.5">
                      <div className="text-[13px] font-medium text-ink">{r.name}</div>
                      <div className="text-[11px] text-faint">
                        {CATS[r.category] ?? r.category} · {r.manager}
                      </div>
                    </td>
                    <td className="px-3 py-2.5">
                      <span className={"rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold uppercase " + LANE_CLS[r.lane]}>
                        {r.lane}
                      </span>
                    </td>
                    <td className="px-3 py-2.5 text-right">
                      <span className="font-mono text-[13px] font-semibold tnum text-ink">
                        {r.current_rate != null ? `${Number(r.current_rate).toFixed(2)}%` : "none"}
                      </span>
                    </td>
                    <td className="w-[90px] px-3 py-2.5 text-live">
                      <Spark points={r.spark} tone="text-live" />
                    </td>
                    <td className="px-3 py-2.5">
                      <span className="inline-flex items-center gap-1.5 font-mono text-[11.5px] text-faint">
                        <span className="h-1.5 w-1.5 rounded-full bg-live" />
                        {ago(r.updated_at)}
                      </span>
                    </td>
                    <td className="px-3 py-2.5">
                      <span className="font-mono text-[11px] text-faint">{r.lastSource ?? "none"}</span>
                    </td>
                    <td className="px-3 py-2.5">
                      {url ? (
                        <a
                          href={url}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-1 text-[11.5px] text-mute hover:text-gold"
                        >
                          open <IconExternal size={11} />
                        </a>
                      ) : (
                        <span className="text-[11.5px] text-faint">none</span>
                      )}
                    </td>
                    <td className="px-3 py-2.5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <form action={setSourceType}>
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="type" value={r.source_type === "manual" ? "auto" : "manual"} />
                          <button
                            title="Toggle auto and manual"
                            className="rounded-md border border-line px-2 py-1 font-mono text-[10.5px] text-faint hover:text-ink"
                          >
                            {r.source_type}
                          </button>
                        </form>
                        <button
                          onClick={() => setEditing(editing === r.id ? null : r.id)}
                          className="rounded-md border border-line px-2 py-1 text-[11px] text-faint hover:text-ink"
                        >
                          Edit
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
              {healthy.length === 0 && (
                <tr>
                  <td colSpan={8} className="px-4 py-10 text-center text-sm text-mute">
                    Nothing here matches.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* the editor opens under the table for a healthy row too */}
        {editing && healthy.some((r) => r.id === editing) && (
          <div className="mt-2 overflow-hidden rounded-xl border border-line bg-panel">
            <LinkEditor
              row={healthy.find((r) => r.id === editing)!}
              pending={pending}
              onCancel={() => setEditing(null)}
              onSave={saveLinks}
            />
          </div>
        )}
      </div>
    </div>
  );
}

function LinkEditor({
  row,
  pending,
  onCancel,
  onSave,
}: {
  row: Src;
  pending: boolean;
  onCancel: () => void;
  onSave: (fd: FormData, id: string) => void;
}) {
  const [rateUrl, setRateUrl] = useState(row.rate_source_url ?? "");
  const [siteUrl, setSiteUrl] = useState(row.site_url ?? "");
  const cls =
    "w-full rounded-lg border border-line bg-panel2 px-3 py-2 font-mono text-[12px] text-ink outline-none placeholder:text-faint focus:border-gold";

  return (
    <div className="border-t border-line bg-raise px-4 py-3">
      <div className="grid gap-3 md:grid-cols-2">
        <div>
          <label className="mb-1.5 block text-[10px] font-semibold uppercase tracking-wider text-faint">
            Rate page
          </label>
          <input
            value={rateUrl}
            onChange={(e) => setRateUrl(e.target.value)}
            placeholder="the exact page the number is printed on"
            className={cls}
          />
        </div>
        <div>
          <label className="mb-1.5 block text-[10px] font-semibold uppercase tracking-wider text-faint">
            Manager site
          </label>
          <input
            value={siteUrl}
            onChange={(e) => setSiteUrl(e.target.value)}
            placeholder="the fund manager's home page"
            className={cls}
          />
        </div>
      </div>
      <div className="mt-3 flex items-center gap-3">
        <span className="flex-1 text-[11px] text-faint">
          Saving touches only these two links. The rate, the lane and the status are untouched.
        </span>
        <button
          onClick={onCancel}
          className="rounded-lg border border-line2 px-2.5 py-1.5 text-[11.5px] text-mute hover:text-ink"
        >
          <span className="flex items-center gap-1.5">
            <IconX size={11} /> Cancel
          </span>
        </button>
        <button
          disabled={pending}
          onClick={() => {
            const fd = new FormData();
            fd.set("id", row.id);
            fd.set("rate_source_url", rateUrl);
            fd.set("site_url", siteUrl);
            onSave(fd, row.id);
          }}
          className="rounded-lg border border-gold bg-gold px-3 py-1.5 text-[12px] font-semibold text-[#191204] hover:brightness-110 disabled:opacity-40"
        >
          {pending ? "Saving" : "Save links"}
        </button>
      </div>
    </div>
  );
}
