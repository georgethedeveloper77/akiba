// Backfill price history from the afx per-stock pages.
//
// Each page at afx.kwayisi.org/nse/<ticker>.html carries a table of the last 10
// trading days for that counter. Sixty-four pages therefore gives us roughly two
// weeks of real, source-verified history, which is enough for the sparkline and
// the range chart to draw something honest on day one instead of a single dot.
//
// It is NOT three months. There is no free source for three months: the NSE's
// own daily PDFs are scanned images and OCR misreads dates (it turned 2026 into
// 2025 and 2024 on the corporate actions block), and the GitHub archive stops in
// 2022. For real depth, buy the NSE historical daily equities file from
// dataservices@nse.co.ke. It is KSh 350.
//
// DRY RUN BY DEFAULT. Nothing is written until you pass --write.
//
//   deno run --allow-net --allow-env --env-file=fructa-admin/.env.local \
//     supabase/scripts/backfill-nse-history.ts
//
//   deno run --allow-net --allow-env --env-file=fructa-admin/.env.local \
//     supabase/scripts/backfill-nse-history.ts --write

import { createClient } from "jsr:@supabase/supabase-js@2.85.0";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";

const WRITE = Deno.args.includes("--write");
const BASE = "https://afx.kwayisi.org/nse";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !key) {
  console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.");
  Deno.exit(1);
}
const db = createClient(url, key);

function num(s: string): number | null {
  const t = s.replace(/,/g, "").replace(/[^\d.\-]/g, "").trim();
  if (!t || t === "-" || t === ".") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

/** afx prints dates as "July 10, 2026". Parse to an ISO day, or null. */
function isoDate(s: string): string | null {
  const t = s.trim();
  if (!t) return null;
  const ms = Date.parse(t);
  if (Number.isNaN(ms)) return null;
  return new Date(ms).toISOString().slice(0, 10);
}

type Row = { asOf: string; close: number; volume: number | null };

/** Header driven, exactly like the daily adapter. If the columns are not where
 *  the header says they are, we would rather parse nothing than parse wrong. */
function parseHistory(html: string, ticker: string): Row[] {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) throw new Error(`${ticker}: failed to parse HTML`);

  for (const table of (doc as any).querySelectorAll("table")) {
    const trs = [...table.querySelectorAll("tr")];
    if (trs.length < 2) continue;

    const head = [...trs[0].querySelectorAll("th, td")].map((c: any) =>
      String(c.textContent).trim().toLowerCase()
    );
    const iDate = head.findIndex((h: string) => h === "date");
    const iPrice = head.findIndex((h: string) => h === "price" || h === "close");
    if (iDate < 0 || iPrice < 0) continue; // not the history table

    const iVol = head.findIndex((h: string) => h === "volume");

    const rows: Row[] = [];
    for (const tr of trs.slice(1)) {
      const cells = [...tr.querySelectorAll("td")].map((c: any) =>
        String(c.textContent).trim()
      );
      if (cells.length <= iPrice) continue;

      const asOf = isoDate(cells[iDate] ?? "");
      const close = num(cells[iPrice] ?? "");
      if (!asOf || close == null || close <= 0) continue;

      rows.push({
        asOf,
        close,
        volume: iVol >= 0 ? num(cells[iVol] ?? "") : null,
      });
    }
    if (rows.length) return rows;
  }

  // No history table is a legitimate outcome for a counter that never trades
  // (MSC, DCON). Return empty rather than throwing: one silent stock must not
  // abort the other sixty three.
  return [];
}

const { data: stocks, error } = await db
  .from("stocks")
  .select("id,ticker")
  .order("ticker");
if (error) {
  console.error("could not read stocks:", error.message);
  Deno.exit(1);
}

console.log(`${WRITE ? "WRITE" : "DRY RUN"}: ${stocks!.length} stocks\n`);

type Px = {
  stock_id: string;
  as_of: string;
  close_kes: number;
  prev_close: number | null;
  volume: number | null;
  source: string;
};
const all: Px[] = [];
const empty: string[] = [];
const failed: string[] = [];

for (const s of stocks!) {
  const ticker = String(s.ticker);
  try {
    const res = await fetch(`${BASE}/${ticker.toLowerCase()}.html`, {
      headers: {
        "User-Agent": "FructaBot/1.0 (+https://fructa.africa; one-off backfill)",
      },
    });
    if (!res.ok) {
      failed.push(`${ticker} HTTP ${res.status}`);
      continue;
    }

    const rows = parseHistory(await res.text(), ticker);
    if (!rows.length) {
      empty.push(ticker);
    } else {
      // Oldest first, so each day's prev_close is the day before it in OUR
      // series. The 10-day table has no change column, and we are not going to
      // invent one: the earliest row keeps a null prev_close, and the app shows
      // no day change for that day rather than a fabricated flat.
      const asc = [...rows].sort((a, b) => a.asOf.localeCompare(b.asOf));
      asc.forEach((r, i) => {
        all.push({
          stock_id: s.id,
          as_of: r.asOf,
          close_kes: r.close,
          prev_close: i > 0 ? asc[i - 1].close : null,
          volume: r.volume,
          source: "afx-nse-history",
        });
      });
    }
    console.log(`  ${ticker.padEnd(6)} ${String(rows.length).padStart(2)} days`);
  } catch (e) {
    failed.push(`${ticker}: ${e instanceof Error ? e.message : String(e)}`);
  }

  // Courteous: one request per second. Sixty four pages, about a minute. We are
  // a guest on someone else's server and this runs once.
  await new Promise((r) => setTimeout(r, 1000));
}

const days = [...new Set(all.map((p) => p.as_of))].sort();
console.log(`\nparsed ${all.length} price points`);
console.log(`covering ${days.length} trading days: ${days[0]} to ${days.at(-1)}`);

if (empty.length) {
  console.log(`\nno history table (untraded counters, expected): ${empty.join(", ")}`);
}
if (failed.length) {
  console.log(`\nFAILED: ${failed.join("; ")}`);
}

// Spot check. If the parser grabbed the wrong column this is where it shows.
const scom = all.filter((p) =>
  stocks!.find((s) => s.id === p.stock_id)?.ticker === "SCOM"
);
if (scom.length) {
  console.log("\nSCOM, cross-check the last row against the board (10 Jul = 35.05)");
  for (const p of scom) {
    console.log(`  ${p.as_of}  ${String(p.close_kes).padStart(8)}`);
  }
}

if (!WRITE) {
  console.log("\nDRY RUN. Nothing written. Re-run with --write once this looks right.");
  Deno.exit(0);
}

// Do not clobber a same-day row already written by the live scraper: that row
// carries a prev_close derived from the exchange's own previous price, which is
// better than one we inferred from a 10-day window. Insert, ignore duplicates.
let wrote = 0;
for (let i = 0; i < all.length; i += 200) {
  const chunk = all.slice(i, i + 200);
  const { error: e, count } = await db
    .from("stock_prices")
    .upsert(chunk, { onConflict: "stock_id,as_of", ignoreDuplicates: true, count: "exact" });
  if (e) {
    console.error(`  write failed at ${i}: ${e.message}`);
    Deno.exit(1);
  }
  wrote += count ?? 0;
}

console.log(`\nwrote ${wrote} new price points (existing rows left alone).`);
console.log("Now trigger Rebuild snapshot so the app sees the history.");
