import { adminClient } from "../_shared/supabase.ts";
import { publishSnapshot } from "../_shared/snapshot.ts";
import type { StockPriceAdapter } from "../_shared/types.ts";
import { nsePriceTableAdapter } from "./adapters/nse-price-table.ts";

// NSE price ingestion. Separate from scrape-aggregator on purpose:
//   * scrape-aggregator writes rate_history and validates against a 0-30%
//     yield band. A share price is not a yield and would be rejected outright.
//   * prices are LICENCE GATED, rates are not. Keeping them in one function
//     would mean one auth surface for two very different legal positions.
//
// ── THE GATE ───────────────────────────────────────────────────────────────
// NSE market data (prices, volumes, anything derived from them) is subject to
// an NSE data redistribution licence. Scraping it does not avoid that licence,
// it is precisely what the licence covers. So this function refuses to run
// unless BOTH of these are true:
//
//   1. app_config `stocks.prices_enabled` = true   (the deliberate switch)
//   2. env NSE_PRICES_URL is set                   (the feed you are licensed for)
//
// Point NSE_PRICES_URL at the feed your agreement actually covers. Do not point
// it at a public page you have no agreement with: the whole reason this refuses
// to run by default is so that pointing it somewhere is a conscious act.
//
// Invoke: pg_cron on trading days, or the admin re-run button. Same shared
// secret as the other functions.
Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }

  const body = await req.json().catch(() => ({} as Record<string, unknown>));
  const trigger = body?.trigger === "manual" ? "manual" : "cron";

  const db = adminClient();
  const source = "ke-nse";
  const startedAt = new Date().toISOString();
  const asOf = new Date(Date.now() + 3 * 3_600_000).toISOString().slice(0, 10);

  // Gate 1: the config switch.
  const { data: cfg } = await db
    .from("app_config")
    .select("value")
    .eq("key", "stocks.prices_enabled")
    .maybeSingle();
  if (cfg?.value !== true) {
    return Response.json({
      source,
      skipped: "stocks.prices_enabled is false",
      note:
        "NSE prices are licence gated. Set the config key only once a redistribution agreement is in place.",
    });
  }

  // Gate 2: the feed.
  const feedUrl = Deno.env.get("NSE_PRICES_URL");
  if (!feedUrl) {
    return Response.json({ source, skipped: "NSE_PRICES_URL not set" });
  }

  const errors: string[] = [];
  const unmapped: string[] = [];

  // ticker -> stock_id. Tickers are the join key, so no fuzzy name matching is
  // needed here (contrast the MMF lane, where sources use casual fund labels).
  const { data: stockRows } = await db.from("stocks").select("id,ticker");
  const idByTicker: Record<string, string> = {};
  for (const s of stockRows ?? []) {
    idByTicker[String(s.ticker).trim().toUpperCase()] = s.id;
  }

  const adapters: StockPriceAdapter[] = [nsePriceTableAdapter(feedUrl)];

  type PxRow = {
    stock_id: string;
    as_of: string;
    close_kes: number;
    prev_close: number | null;
    day_high: number | null;
    day_low: number | null;
    volume: number | null;
    source: string;
  };
  const points: PxRow[] = [];

  for (const adapter of adapters) {
    try {
      const rows = await adapter.fetchRows();
      for (const row of rows) {
        const id = idByTicker[row.ticker.trim().toUpperCase()];
        if (!id) {
          unmapped.push(`${adapter.id}:${row.ticker}`);
          continue;
        }
        // Sanity band. A share price is not a yield, so the 0-30 rule from
        // validate.ts does not apply. Reject the impossible only.
        if (!Number.isFinite(row.close) || row.close <= 0 || row.close > 100_000) {
          errors.push(`${row.ticker}: close out of band (${row.close})`);
          continue;
        }
        points.push({
          stock_id: id,
          as_of: row.asOf ?? asOf,
          close_kes: row.close,
          prev_close: row.prevClose ?? null,
          day_high: row.high ?? null,
          day_low: row.low ?? null,
          volume: row.volume ?? null,
          source: adapter.id,
        });
      }
    } catch (e) {
      errors.push(`${adapter.id}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  // Backfill prev_close from the previous stored row when the feed omits it, so
  // the app's day-change is right even on a bare (ticker, price) feed.
  if (points.length) {
    const ids = [...new Set(points.map((p) => p.stock_id))];
    const { data: lastRows } = await db
      .from("stock_prices")
      .select("stock_id,close_kes,as_of")
      .in("stock_id", ids)
      .order("as_of", { ascending: false });
    const lastByStock: Record<string, { close: number; asOf: string }> = {};
    for (const r of lastRows ?? []) {
      if (!lastByStock[r.stock_id]) {
        lastByStock[r.stock_id] = { close: Number(r.close_kes), asOf: r.as_of };
      }
    }
    for (const p of points) {
      const prior = lastByStock[p.stock_id];
      if (p.prev_close == null && prior && prior.asOf < p.as_of) {
        p.prev_close = prior.close;
      }
    }

    await db.from("stock_prices").upsert(points, { onConflict: "stock_id,as_of" });
  }

  // Republish so the app sees the new closes.
  let snapshot = null;
  if (points.length) {
    try {
      snapshot = await publishSnapshot(db);
    } catch (e) {
      errors.push(`snapshot: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  await db.from("scraper_runs").insert({
    source,
    trigger,
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    written: points.length,
    rejected: 0,
    unmapped,
    errors,
    ok: errors.length === 0,
  });

  return Response.json({
    source,
    trigger,
    written: points.length,
    unmapped,
    snapshot,
    errors,
  });
});
