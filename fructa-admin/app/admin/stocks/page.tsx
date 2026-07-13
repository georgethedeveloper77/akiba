import Link from "next/link";
import { supabaseAdmin } from "@/lib/supabase/server";
import { StocksTable, type StockRow } from "./StocksTable";
import { AddStock } from "./AddStock";
import { ImportDividends } from "./ImportDividends";

export const dynamic = "force-dynamic";

type DivRow = { stock_id: string; financial_year: number; dps_kes: number };
type PxRow = {
  stock_id: string;
  close_kes: number;
  prev_close: number | null;
  as_of: string;
};

/** EAT is UTC+3. A trading day is a day in Nairobi, not on the server. */
function eatToday(): string {
  return new Date(Date.now() + 3 * 3_600_000).toISOString().slice(0, 10);
}

function daysOld(iso: string): number {
  const a = new Date(`${iso}T00:00:00Z`).getTime();
  const b = new Date(`${eatToday()}T00:00:00Z`).getTime();
  return Math.round((b - a) / 86_400_000);
}

export default async function StocksPage() {
  const db = supabaseAdmin();

  // The scraper has been writing 64 prices every weekday evening and this page
  // showed none of them. No price column, no as-of, no way to notice that afx
  // moved its table and we started storing the volume as the close. Every other
  // lane in Fructa surfaces its own health; this one was flying blind, and the
  // first person to find a bad price would have been a user.
  //
  // Only the last 14 days are read. The full table grows forever and we need
  // exactly two marks per stock: the latest, and the one before it.
  const since = new Date(Date.now() - 14 * 86_400_000).toISOString().slice(0, 10);

  const [
    { data: stockData, error },
    { data: divData },
    { data: cfg },
    { data: pxData },
  ] = await Promise.all([
    db.from("stocks")
      .select("id,ticker,name,sector,segment,logo_url,brand_color,shares_outstanding,eps,eps_year,active")
      .order("name"),
    db.from("stock_dividends").select("stock_id,financial_year,dps_kes"),
    db.from("app_config").select("value").eq("key", "stocks.prices_enabled").maybeSingle(),
    db.from("stock_prices")
      .select("stock_id,close_kes,prev_close,as_of")
      .gte("as_of", since)
      // DESCENDING, so the first row seen per stock is the newest. Ascending
      // with a row cap would keep the OLDEST rows and quietly hide today's.
      .order("as_of", { ascending: false }),
  ]);

  const pricesEnabled = cfg?.value === true;

  const pxByStock = new Map<string, PxRow>();
  for (const p of (pxData ?? []) as PxRow[]) {
    if (!pxByStock.has(p.stock_id)) pxByStock.set(p.stock_id, p);
  }

  // The freshest mark anywhere. This is the honest answer to "did the scraper
  // run", and it is a fact about the DATA, not about a cron log that can say
  // "ok" while having written nothing.
  const lastPriceDay = [...pxByStock.values()]
    .map((p) => p.as_of)
    .sort()
    .at(-1) ?? null;

  // Latest financial year per stock, with all its kinds summed. Mirrors what
  // publish-snapshot computes, so admin and app agree on the headline dividend.
  const byStock = new Map<string, DivRow[]>();
  for (const d of (divData ?? []) as DivRow[]) {
    const arr = byStock.get(d.stock_id) ?? [];
    arr.push(d);
    byStock.set(d.stock_id, arr);
  }

  const rows: StockRow[] = ((stockData ?? []) as Omit<
    StockRow,
    "dps_latest" | "dps_year" | "div_count" | "close_kes" | "prev_close" | "price_as_of" | "pe"
  >[]).map((s) => {
    const divs = byStock.get(s.id) ?? [];
    const year = divs.length ? Math.max(...divs.map((d) => d.financial_year)) : null;
    const dps = year == null
      ? null
      : Number(divs.filter((d) => d.financial_year === year)
        .reduce((a, d) => a + Number(d.dps_kes), 0).toFixed(4));

    const px = pxByStock.get(s.id) ?? null;
    const close = px ? Number(px.close_kes) : null;

    // P/E only on POSITIVE earnings. A negative EPS does not give a small P/E,
    // it gives a meaningless one, and rendering "-4.2x" invites a reader to
    // treat a loss-making company as cheap.
    const eps = s.eps == null ? null : Number(s.eps);
    const pe = close != null && eps != null && eps > 0
      ? Number((close / eps).toFixed(2))
      : null;

    return {
      ...s,
      dps_latest: dps,
      dps_year: year,
      div_count: divs.length,
      close_kes: close,
      prev_close: px?.prev_close == null ? null : Number(px.prev_close),
      price_as_of: px?.as_of ?? null,
      pe,
    };
  });

  const total = rows.length;
  const live = rows.filter((s) => s.active).length;
  const withDiv = rows.filter((s) => s.dps_latest != null).length;
  const withShares = rows.filter((s) => s.shares_outstanding != null).length;
  const withEps = rows.filter((s) => s.eps != null).length;
  const coverage = total ? Math.round((withDiv / total) * 100) : 0;

  // Priced on the LATEST day we have, not "priced ever". A stock carrying a
  // price from three weeks ago is not a priced stock, it is a stale one, and
  // counting it as covered is how a dead scraper looks healthy.
  const pricedToday = lastPriceDay
    ? rows.filter((s) => s.price_as_of === lastPriceDay).length
    : 0;
  const staleDays = lastPriceDay ? daysOld(lastPriceDay) : null;

  // Weekends are not a fault. The NSE trades Monday to Friday, so a Sunday will
  // legitimately show Friday's board. Anything past 4 days has skipped a
  // weekday, which is the actual signal.
  const priceStale = staleDays != null && staleDays > 4;

  const kpis: { label: string; value: number | string; sub?: string; tone?: "warn" | "ok" | "bad" }[] = [
    { label: "Stocks", value: total },
    { label: "In app", value: live },
    {
      label: "Priced",
      value: pricesEnabled ? `${pricedToday}/${total}` : "off",
      sub: !pricesEnabled
        ? "kill switch is off"
        : lastPriceDay == null
        ? "no price ever written"
        : `as of ${lastPriceDay}${staleDays !== null && staleDays > 0 ? `, ${staleDays}d ago` : ", today"}`,
      tone: !pricesEnabled
        ? undefined
        : lastPriceDay == null || priceStale
        ? "bad"
        : pricedToday < total * 0.7
        ? "warn"
        : "ok",
    },
    { label: "With dividend", value: withDiv, sub: `${coverage}% coverage`, tone: coverage >= 60 ? "ok" : "warn" },
    { label: "EPS set", value: withEps, sub: "needed for P/E" },
    { label: "Shares out set", value: withShares, sub: "needed for market cap" },
  ];

  return (
    <div className="mx-auto max-w-6xl">
      {error && (
        <p className="mb-4 rounded-lg border border-bad/40 bg-bad/10 px-4 py-3 text-sm text-bad">{error.message}</p>
      )}

      {/* This banner used to say NSE prices "need a redistribution licence" and
          that the snapshot was withholding them pending an agreement. That was
          the first thing anyone read on this page and it was not true. Fructa
          publishes end-of-day closes, which are facts of public record printed
          in the Kenyan press every day, and the day change and sparkline are our
          own derived figures on our own stored series.

          `stocks.prices_enabled` is a KILL SWITCH. Flip it off when a parse goes
          wrong or a source goes down, and every price surface in the app
          disappears on the next rebuild with no release. */}
      {!pricesEnabled && (
        <div className="mb-3 rounded-xl border border-warn/30 bg-warn/5 px-4 py-3">
          <div className="text-[11px] uppercase tracking-wider text-warn">Prices are switched off</div>
          <p className="mt-1 text-sm leading-relaxed text-mute">
            The <code className="text-faint">stocks.prices_enabled</code> kill switch is off, so the scraper does not
            run and the snapshot publishes no price, day change, market cap, sparkline or dividend yield. Stock pages
            still show company facts, declared dividends and where to buy. Turn it back on in Config and the app picks
            prices up on the next rebuild, with no release.
          </p>
        </div>
      )}

      {/* The alarm that was missing. A silent scraper used to look identical to
          a healthy one from this page, which is exactly how the pg_cron outage
          ran for six days without anyone noticing. Say it loudly, where someone
          is actually looking. */}
      {pricesEnabled && (lastPriceDay == null || priceStale) && (
        <div className="mb-3 rounded-xl border border-bad/40 bg-bad/10 px-4 py-3">
          <div className="text-[11px] uppercase tracking-wider text-bad">
            {lastPriceDay == null ? "No prices have ever been written" : "Prices are stale"}
          </div>
          <p className="mt-1 text-sm leading-relaxed text-mute">
            {lastPriceDay == null ? (
              <>
                Prices are switched on but <code className="text-faint">stock_prices</code> is empty. The{" "}
                <code className="text-faint">ke-nse</code> scraper has never written a row.{" "}
                <Link href="/admin/scrapers" className="text-gold underline underline-offset-2">
                  Run it from Scrapers
                </Link>{" "}
                and check the result.
              </>
            ) : (
              <>
                The newest price in the database is from <span className="text-ink">{lastPriceDay}</span>, which is{" "}
                <span className="text-ink">{staleDays} days</span> ago. The NSE trades Monday to Friday, so a weekend
                gap is normal and this is not one. The app is showing those old numbers as though they were current.{" "}
                <Link href="/admin/scrapers" className="text-gold underline underline-offset-2">
                  Check the ke-nse run on Scrapers
                </Link>.
              </>
            )}
          </p>
        </div>
      )}

      <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-5">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-xl border border-line bg-panel px-4 py-3">
            <div className="text-[10px] uppercase tracking-wider text-faint">{k.label}</div>
            <div className={"mt-0.5 text-2xl font-semibold tnum " + (k.tone === "warn" ? "text-warn" : k.tone === "ok" ? "text-live" : "text-ink")}>
              {k.value}
            </div>
            {k.sub && <div className="text-[11px] text-faint">{k.sub}</div>}
          </div>
        ))}
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="flex flex-1 flex-wrap gap-x-5 gap-y-1 rounded-xl border border-line bg-panel px-4 py-2.5 text-xs text-mute">
          {["MIM", "AIM", "GEMS"].map((seg) => (
            <span key={seg}>
              <span className="tnum font-medium text-ink">{rows.filter((s) => s.segment === seg).length}</span> {seg}
            </span>
          ))}
        </div>
        <AddStock />
      </div>

      <ImportDividends />

      <StocksTable rows={rows} />
    </div>
  );
}
