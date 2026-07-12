import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseAdmin } from "@/lib/supabase/server";
import { updateStock, saveDividend, deleteDividend, deleteStock } from "../actions";

export const dynamic = "force-dynamic";

const SEGMENTS: [string, string][] = [
  ["MIM", "Main Investment Market"],
  ["AIM", "Alternative Investment Market"],
  ["GEMS", "Growth Enterprise Market"],
];
const KINDS: [string, string][] = [
  ["final", "Final"],
  ["interim", "Interim"],
  ["special", "Special"],
];

type Div = {
  id: string;
  financial_year: number;
  kind: string;
  dps_kes: number;
  declared_on: string | null;
  book_closure: string | null;
  payment_date: string | null;
  source_url: string | null;
};

export default async function StockDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const db = supabaseAdmin();

  const [{ data: s }, { data: divs }, { data: cfg }] = await Promise.all([
    db.from("stocks").select("*").eq("id", id).maybeSingle(),
    db.from("stock_dividends").select("*").eq("stock_id", id)
      .order("financial_year", { ascending: false }).order("kind"),
    db.from("app_config").select("value").eq("key", "stocks.prices_enabled").maybeSingle(),
  ]);
  if (!s) notFound();

  const pricesEnabled = cfg?.value === true;
  const rows = (divs ?? []) as Div[];
  const thisYear = new Date().getFullYear();

  const field = "w-full rounded-md border border-line bg-panel2 px-3 py-2 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60";
  const label = "mb-1 block text-[11px] uppercase tracking-wider text-faint";

  return (
    <div className="mx-auto max-w-4xl space-y-4">
      <div className="flex items-center gap-3">
        <Link href="/admin/stocks" className="text-sm text-faint hover:text-ink">Stocks</Link>
        <span className="text-faint">/</span>
        <h1 className="text-lg font-semibold text-ink">{s.name}</h1>
        <span className="rounded-md border border-line bg-panel2 px-2 py-0.5 font-mono text-xs text-mute">{s.ticker}</span>
      </div>

      {/* Profile. Section-scoped writer: touches only these columns. */}
      <form action={updateStock} className="rounded-xl border border-line bg-panel p-5">
        <input type="hidden" name="id" value={s.id} />
        <div className="mb-4 flex items-baseline justify-between">
          <h2 className="text-base font-semibold text-ink">Profile</h2>
          <span className="text-xs text-faint">public data, always published</span>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className={label}>Name</label>
            <input name="name" defaultValue={s.name} className={field} />
          </div>
          <div>
            <label className={label}>Ticker</label>
            <input name="ticker" defaultValue={s.ticker} className={field + " font-mono"} />
          </div>
          <div>
            <label className={label}>Sector</label>
            <input name="sector" defaultValue={s.sector ?? ""} placeholder="Telecommunications" className={field} />
          </div>
          <div>
            <label className={label}>Segment</label>
            <select name="segment" defaultValue={s.segment ?? "MIM"} className={field}>
              {SEGMENTS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          </div>
          <div>
            <label className={label}>Shares outstanding</label>
            <input name="shares_outstanding" inputMode="numeric" defaultValue={s.shares_outstanding ?? ""}
              placeholder="40065428000" className={field + " tnum"} />
            <p className="mt-1 text-[11px] text-faint">Market cap needs this and a price. Leave blank to hide market cap.</p>
          </div>
          <div>
            <label className={label}>Listed on</label>
            <input name="listed_on" type="date" defaultValue={s.listed_on ?? ""} className={field} />
          </div>
          <div>
            <label className={label}>ISIN</label>
            <input name="isin" defaultValue={s.isin ?? ""} className={field + " font-mono"} />
          </div>
          <div>
            <label className={label}>Brand color</label>
            <input name="brand_color" defaultValue={s.brand_color ?? ""} placeholder="#3DDC97" className={field + " font-mono"} />
          </div>
          <div>
            <label className={label}>Logo URL</label>
            <input name="logo_url" defaultValue={s.logo_url ?? ""} className={field} />
          </div>
          <div>
            <label className={label}>Website</label>
            <input name="website" defaultValue={s.website ?? ""} className={field} />
          </div>
          <div className="sm:col-span-2">
            <label className={label}>Investor relations URL</label>
            <input name="ir_url" defaultValue={s.ir_url ?? ""} className={field} />
            <p className="mt-1 text-[11px] text-faint">Where the annual report and dividend announcements live. This is your dividend source.</p>
          </div>
          <div className="sm:col-span-2">
            <label className={label}>About</label>
            <textarea name="about" rows={3} defaultValue={s.about ?? ""}
              placeholder="One plain paragraph. What the company does, in words a first-time investor understands."
              className={field} />
          </div>
        </div>

        <div className="mt-5 flex items-center justify-between">
          <button className="rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20">
            Save profile
          </button>
          <span className="text-xs text-faint">Saving republishes the snapshot.</span>
        </div>
      </form>

      {/* Dividends. The lane that makes this page useful with no price feed. */}
      <div className="rounded-xl border border-line bg-panel p-5">
        <div className="mb-4 flex items-baseline justify-between">
          <h2 className="text-base font-semibold text-ink">Dividends</h2>
          <span className="text-xs text-faint">declared per share, KES</span>
        </div>

        {rows.length > 0 ? (
          <div className="mb-4 overflow-hidden rounded-lg border border-line">
            <table className="w-full text-xs">
              <thead>
                <tr className="border-b border-line bg-panel2 text-left text-[10px] uppercase tracking-wider text-faint">
                  <th className="px-3 py-2">Year</th>
                  <th className="px-3 py-2">Kind</th>
                  <th className="px-3 py-2">DPS</th>
                  <th className="px-3 py-2">Paid</th>
                  <th className="px-3 py-2">Source</th>
                  <th className="px-3 py-2" />
                </tr>
              </thead>
              <tbody>
                {rows.map((d) => (
                  <tr key={d.id} className="border-b border-line/60 last:border-0">
                    <td className="tnum px-3 py-2 text-ink">FY{d.financial_year}</td>
                    <td className="px-3 py-2 text-mute">{d.kind}</td>
                    <td className="tnum px-3 py-2 font-medium text-ink">{Number(d.dps_kes).toFixed(2)}</td>
                    <td className="px-3 py-2 text-faint">{d.payment_date ?? "not set"}</td>
                    <td className="px-3 py-2">
                      {d.source_url
                        ? <a href={d.source_url} target="_blank" rel="noreferrer" className="text-mute hover:text-gold">link</a>
                        : <span className="text-faint">none</span>}
                    </td>
                    <td className="px-3 py-2 text-right">
                      <form action={deleteDividend}>
                        <input type="hidden" name="id" value={d.id} />
                        <input type="hidden" name="stock_id" value={s.id} />
                        <button className="rounded-md border border-bad/40 px-2 py-0.5 text-[11px] text-bad hover:bg-bad/10">
                          Delete
                        </button>
                      </form>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="mb-4 rounded-lg border border-line bg-panel2 px-3 py-3 text-xs text-mute">
            No dividends recorded. Add one from the company annual report or its dividend announcement.
          </p>
        )}

        <form action={saveDividend} className="grid gap-3 sm:grid-cols-4">
          <input type="hidden" name="stock_id" value={s.id} />
          <div>
            <label className={label}>Financial year</label>
            <input name="financial_year" inputMode="numeric" defaultValue={thisYear - 1} className={field + " tnum"} />
          </div>
          <div>
            <label className={label}>Kind</label>
            <select name="kind" defaultValue="final" className={field}>
              {KINDS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          </div>
          <div>
            <label className={label}>DPS (KES)</label>
            <input name="dps_kes" inputMode="decimal" placeholder="1.20" className={field + " tnum"} />
          </div>
          <div>
            <label className={label}>Payment date</label>
            <input name="payment_date" type="date" className={field} />
          </div>
          <div className="sm:col-span-3">
            <label className={label}>Source URL</label>
            <input name="source_url" placeholder="Annual report or announcement PDF" className={field} />
          </div>
          <div className="flex items-end">
            <button className="w-full rounded-md border border-gold/50 bg-gold/10 px-4 py-2 text-sm font-medium text-gold hover:bg-gold/20">
              Save dividend
            </button>
          </div>
        </form>

        <p className="mt-3 text-[11px] leading-relaxed text-faint">
          Re-entering the same year and kind corrects that record rather than duplicating it. The app sums every kind in
          the most recent year into one headline figure.
          {!pricesEnabled && " Dividend yield stays hidden until prices are licensed, since a yield needs a price."}
        </p>
      </div>

      {/* Danger zone */}
      <form action={deleteStock} className="rounded-xl border border-bad/30 bg-bad/5 p-5">
        <input type="hidden" name="id" value={s.id} />
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="text-sm font-semibold text-ink">Delete this stock</h2>
            <p className="mt-1 text-xs text-mute">Removes the company, its dividends and any stored prices. Cannot be undone.</p>
          </div>
          <button className="shrink-0 rounded-md border border-bad/40 px-3 py-1.5 text-xs text-bad hover:bg-bad/10">
            Delete stock
          </button>
        </div>
      </form>
    </div>
  );
}
