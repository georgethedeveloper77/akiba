"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { toggleStockActive } from "./actions";
import { IconChevronUp, IconChevronDown } from "../_icons";

export type StockRow = {
  id: string;
  ticker: string;
  name: string;
  sector: string | null;
  segment: string | null;
  logo_url: string | null;
  brand_color: string | null;
  shares_outstanding: number | null;
  eps: number | null;
  eps_year: number | null;
  active: boolean;
  dps_latest: number | null;
  dps_year: number | null;
  div_count: number;
  // The price block. Read straight from stock_prices, not from the snapshot:
  // this table is how you find out the SCRAPER is wrong, and reading the
  // published file would show you the same wrong number it already shipped.
  close_kes: number | null;
  prev_close: number | null;
  price_as_of: string | null;
  pe: number | null;
};

const TINTS = ["#E7B24C", "#5B8DEF", "#A78BFA", "#3DD6C4", "#3DDC97"];
function hashTint(seed: string) {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  return TINTS[h % TINTS.length];
}

type SortKey = "name" | "ticker" | "sector" | "dps" | "price" | "change";

/** Day change from OUR two stored marks. Null when we hold only one, which is
 *  the honest answer on a counter's first day and on a share that did not trade.
 *  Never zero: "did not trade" and "closed flat" are different facts. */
function changePct(s: StockRow): number | null {
  if (s.close_kes == null || s.prev_close == null || s.prev_close <= 0) return null;
  return ((s.close_kes - s.prev_close) / s.prev_close) * 100;
}

export function StocksTable({ rows }: { rows: StockRow[] }) {
  const [q, setQ] = useState("");
  const [seg, setSeg] = useState<string>("all");
  // The freshest day in the data. Any stock whose price is older than this did
  // not trade on the last board, and the table says so rather than presenting a
  // stale number in the same style as a live one.
  const newest = useMemo(
    () => rows.map((r) => r.price_as_of).filter(Boolean).sort().at(-1) ?? null,
    [rows],
  );
  const [sort, setSort] = useState<{ key: SortKey; dir: 1 | -1 }>({ key: "name", dir: 1 });

  const sectors = useMemo(() => {
    const s = new Set<string>();
    for (const r of rows) if (r.sector) s.add(r.sector);
    return [...s].sort();
  }, [rows]);
  const [sector, setSector] = useState<string>("all");

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    const base = rows.filter((s) => {
      if (seg !== "all" && s.segment !== seg) return false;
      if (sector !== "all" && s.sector !== sector) return false;
      if (needle && !`${s.name} ${s.ticker}`.toLowerCase().includes(needle)) return false;
      return true;
    });
    base.sort((a, b) => {
      let r = 0;
      switch (sort.key) {
        case "name": r = a.name.localeCompare(b.name); break;
        case "ticker": r = a.ticker.localeCompare(b.ticker); break;
        case "sector": r = (a.sector ?? "").localeCompare(b.sector ?? ""); break;
        case "dps": {
          const av = a.dps_latest, bv = b.dps_latest;
          if (av == null && bv == null) { r = 0; break; }
          if (av == null) return 1;
          if (bv == null) return -1;
          r = av - bv; break;
        }
        case "price": {
          const av = a.close_kes, bv = b.close_kes;
          if (av == null && bv == null) { r = 0; break; }
          if (av == null) return 1;   // no price always sinks, either direction
          if (bv == null) return -1;
          r = av - bv; break;
        }
        case "change": {
          const av = changePct(a), bv = changePct(b);
          if (av == null && bv == null) { r = 0; break; }
          if (av == null) return 1;
          if (bv == null) return -1;
          r = av - bv; break;
        }
      }
      return r * sort.dir;
    });
    return base;
  }, [rows, seg, sector, q, sort]);

  const by = (key: SortKey) => setSort((s) => (s.key === key ? { key, dir: (s.dir * -1) as 1 | -1 } : { key, dir: 1 }));
  const Th = ({ k, children }: { k: SortKey; children: React.ReactNode }) => (
    <th className="px-3 py-3">
      <button onClick={() => by(k)} className="inline-flex items-center gap-1 font-medium uppercase tracking-wider hover:text-mute">
        {children}
        {sort.key === k && <span className="text-gold">{sort.dir === 1 ? <IconChevronUp size={12} /> : <IconChevronDown size={12} />}</span>}
      </button>
    </th>
  );

  const segBtn = (key: string, label: string) => (
    <button key={key} onClick={() => setSeg(key)}
      className={"rounded-md px-2.5 py-1 text-sm " + (seg === key ? "bg-panel2 text-ink" : "text-mute hover:text-ink")}>
      {label}
    </button>
  );

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-2">
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name or ticker"
          className="w-64 rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60" />

        <div className="flex flex-wrap items-center gap-0.5 rounded-lg border border-line bg-panel p-0.5">
          {segBtn("all", "All")}
          {segBtn("MIM", "MIM")}
          {segBtn("AIM", "AIM")}
          {segBtn("GEMS", "GEMS")}
        </div>

        {sectors.length > 0 && (
          <select value={sector} onChange={(e) => setSector(e.target.value)}
            className="rounded-md border border-line bg-panel2 px-2.5 py-1.5 text-sm text-ink outline-none focus:border-gold/60">
            <option value="all">All sectors</option>
            {sectors.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        )}

        <span className="tnum ml-auto text-xs text-faint">{filtered.length} stocks</span>
      </div>

      <div className="overflow-hidden rounded-xl border border-line bg-panel">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-line text-left text-[11px] text-faint">
              <Th k="name">Company</Th>
              <Th k="ticker">Ticker</Th>
              <Th k="sector">Sector</Th>
              <Th k="price">Price</Th>
              <Th k="change">Day</Th>
              <Th k="dps">Dividend</Th>
              <th className="px-3 py-3 font-medium uppercase tracking-wider">P / E</th>
              <th className="px-3 py-3 font-medium uppercase tracking-wider">Shares out</th>
              <th className="px-3 py-3 font-medium uppercase tracking-wider">Status</th>
              <th className="px-3 py-3" />
            </tr>
          </thead>
          <tbody>
            {filtered.map((s) => {
              const color = s.brand_color ?? hashTint(s.name);
              return (
                <tr key={s.id} className="border-b border-line/60 last:border-0 hover:bg-panel2/30">
                  <td className="px-3 py-3">
                    <div className="flex items-center gap-3">
                      <span className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full border border-line"
                        style={s.logo_url ? { background: "#fff" } : { background: `color-mix(in srgb, ${color} 18%, transparent)`, color }}>
                        {s.logo_url
                          ? <img src={s.logo_url} alt="" className="h-8 w-8 object-contain p-0.5" />
                          : <span className="text-xs font-semibold">{(s.name || "?").slice(0, 1).toUpperCase()}</span>}
                      </span>
                      <div className="min-w-0">
                        <div className="font-medium text-ink">{s.name}</div>
                        <div className="text-xs text-faint">{s.segment ?? "no segment"}</div>
                      </div>
                    </div>
                  </td>

                  <td className="px-3 py-3">
                    <span className="rounded-md border border-line bg-panel2 px-2 py-0.5 font-mono text-xs text-mute">{s.ticker}</span>
                  </td>

                  <td className="px-3 py-3 text-mute">{s.sector ?? "not set"}</td>

                  {/* Price. The VWAP, not a last trade: the NSE daily list has
                      no closing-price column. A stock whose newest mark is older
                      than the board's newest day is called out, because a stale
                      price rendered like a live one is how a broken scraper
                      hides. */}
                  <td className="px-3 py-3">
                    {s.close_kes != null ? (
                      <div className="flex flex-col leading-tight">
                        <span className="tnum text-sm text-ink">{s.close_kes.toFixed(2)}</span>
                        <span className={"text-[10px] " + (newest && s.price_as_of !== newest ? "text-warn" : "text-faint")}>
                          {newest && s.price_as_of !== newest ? `stale ${s.price_as_of}` : s.price_as_of}
                        </span>
                      </div>
                    ) : (
                      <span className="text-xs text-faint">no price</span>
                    )}
                  </td>

                  {/* Day change. Blank, never 0.00%, when we hold one mark: a
                      share that did not trade did not close flat. */}
                  <td className="px-3 py-3">
                    {(() => {
                      const ch = changePct(s);
                      if (ch == null) {
                        return <span className="text-xs text-faint">{s.close_kes == null ? "" : "no prior"}</span>;
                      }
                      const tone = ch > 0 ? "text-live" : ch < 0 ? "text-bad" : "text-mute";
                      return (
                        <span className={"tnum text-sm " + tone}>
                          {ch > 0 ? "+" : ""}{ch.toFixed(2)}%
                        </span>
                      );
                    })()}
                  </td>

                  <td className="px-3 py-3">
                    {s.dps_latest != null ? (
                      <div className="flex flex-col leading-tight">
                        <span className="tnum text-sm text-ink">{s.dps_latest.toFixed(2)} KES</span>
                        <span className="text-[10px] text-faint">
                          FY{s.dps_year} {"\u00B7"} {s.div_count} {s.div_count === 1 ? "record" : "records"}
                        </span>
                      </div>
                    ) : (
                      <span className="text-xs text-faint">no dividend yet</span>
                    )}
                  </td>

                  {/* P/E. Suppressed on a loss, not shown as a negative: a
                      negative multiple is meaningless, and printing "-4.2x"
                      invites a reader to see a loss-making company as cheap. */}
                  <td className="px-3 py-3">
                    {s.pe != null ? (
                      <div className="flex flex-col leading-tight">
                        <span className="tnum text-sm text-ink">{s.pe.toFixed(1)}</span>
                        {s.eps_year != null && (
                          <span className="text-[10px] text-faint">EPS FY{s.eps_year}</span>
                        )}
                      </div>
                    ) : s.eps != null && s.eps <= 0 ? (
                      <span className="text-xs text-warn">loss making</span>
                    ) : (
                      <span className="text-xs text-faint">{s.eps == null ? "no EPS" : "no price"}</span>
                    )}
                  </td>

                  <td className="px-3 py-3">
                    {s.shares_outstanding != null
                      ? <span className="tnum text-xs text-mute">{(s.shares_outstanding / 1e9).toFixed(2)}B</span>
                      : <span className="text-xs text-faint">not set</span>}
                  </td>

                  <td className="px-3 py-3">
                    <div className="flex items-center gap-2">
                      <span className={"text-xs " + (s.active ? "text-live" : "text-faint")}>{s.active ? "live" : "hidden"}</span>
                      <form action={toggleStockActive}>
                        <input type="hidden" name="id" value={s.id} />
                        <input type="hidden" name="value" value={(!s.active).toString()} />
                        <button className="rounded-md border border-line px-2 py-0.5 text-xs text-mute hover:text-ink">
                          {s.active ? "Hide" : "Show"}
                        </button>
                      </form>
                    </div>
                  </td>

                  <td className="px-3 py-3 text-right">
                    <Link href={`/admin/stocks/${s.id}`} className="text-xs text-mute hover:text-gold">Edit</Link>
                  </td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr><td colSpan={10} className="px-4 py-10 text-center text-sm text-mute">No stocks match.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
