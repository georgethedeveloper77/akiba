// Dry run for the NSE price adapter. Fetches the live board, prints exactly
// what it parsed, and WRITES NOTHING.
//
// Run this before you ever let scrape-nse touch the database:
//
//   deno run --allow-net --allow-env --env-file=fructa-admin/.env.local \
//     supabase/scripts/test-nse-adapter.ts
//
// Read the output. Check three things with your own eyes:
//   1. The row count is around 60. Fewer means the layout moved.
//   2. Spot-check two or three prices against nse.co.ke or the newspaper.
//      SCOM and EQTY are the easy ones to eyeball.
//   3. The unmapped list is what you expect. ETFs (GLD, SMWF), preference
//      shares (KPLC-P4, KPLC-P7) and the REIT (LAPR) SHOULD be unmapped: they
//      are not company shares and are deliberately not in `stocks`. Anything
//      else in that list is a new listing we need to add.
//
// Only once this looks right should you deploy the function.

// Full specifier: scripts/ sits outside functions/, so the deno.json import
// map does not apply here and a bare specifier will not resolve.
import { createClient } from "jsr:@supabase/supabase-js@2.85.0";
import { afxNseAdapter } from "../functions/scrape-nse/adapters/afx-nse.ts";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const feed = Deno.env.get("NSE_PRICES_URL") ?? "https://afx.kwayisi.org/nse/";

console.log(`feed: ${feed}\n`);

const rows = await afxNseAdapter(feed).fetchRows();
console.log(`parsed ${rows.length} rows\n`);

// Widest price first: if the parser has grabbed the wrong column, an absurd
// number at the top of this list is the fastest way to see it.
const byPrice = [...rows].sort((a, b) => b.close - a.close);
console.log("highest 5 closes (sanity: KURV ~1355, KUKZ ~390, SCBK ~300)");
for (const r of byPrice.slice(0, 5)) {
  console.log(`  ${r.ticker.padEnd(6)} ${String(r.close).padStart(10)}`);
}
console.log("\nlowest 5 closes (sanity: MSC ~0.28, TCL ~0.71)");
for (const r of byPrice.slice(-5)) {
  console.log(`  ${r.ticker.padEnd(6)} ${String(r.close).padStart(10)}`);
}

// prev_close now comes from the change column, so day change is right on day
// one. Print it so you can eyeball it against afx's own gainers list.
const moved = rows.filter((r) => r.prevClose != null);
console.log(`\nday change computed for ${moved.length} of ${rows.length} rows`);
console.log("top 5 movers (cross-check against afx's own Top Gainers table)");
const pct = (r: typeof rows[number]) =>
  r.prevClose ? ((r.close - r.prevClose) / r.prevClose) * 100 : 0;
for (const r of [...moved].sort((a, b) => pct(b) - pct(a)).slice(0, 5)) {
  console.log(`  ${r.ticker.padEnd(6)} ${String(r.close).padStart(9)}  ${pct(r).toFixed(2).padStart(7)}%`);
}

console.log("\nfull board");
console.log("  ticker    close       volume");
for (const r of [...rows].sort((a, b) => a.ticker.localeCompare(b.ticker))) {
  const vol = r.volume == null ? "(none)" : r.volume.toLocaleString();
  console.log(`  ${r.ticker.padEnd(8)} ${String(r.close).padStart(9)}  ${vol.padStart(12)}`);
}

// Match against the real stocks table, so you see the unmapped list for real
// rather than guessing at it. Read-only: this only SELECTs.
if (url && key) {
  const db = createClient(url, key);
  const { data } = await db.from("stocks").select("id,ticker");
  const known = new Set((data ?? []).map((s) => String(s.ticker).toUpperCase()));

  const unmapped = rows.filter((r) => !known.has(r.ticker.toUpperCase()));
  const missing = [...known].filter(
    (t) => !rows.some((r) => r.ticker.toUpperCase() === t),
  );

  console.log(`\nstocks in the table: ${known.size}`);
  console.log(`matched: ${rows.length - unmapped.length}`);

  console.log(`\nUNMAPPED (on the board, not in our table): ${unmapped.length}`);
  for (const r of unmapped) {
    console.log(`  ${r.ticker.padEnd(8)} ${r.close}`);
  }
  console.log("  Expected here: nothing. GLD/SMWF/KPLC-P4/KPLC-P7/LAPR are");
  console.log("  filtered by the ticker regex and never reach this list.");
  console.log("  Anything that DOES appear is a new listing to add.");

  console.log(`\nNO PRICE TODAY (in our table, not on the board): ${missing.length}`);
  for (const t of missing) console.log(`  ${t}`);
  console.log("  Untraded counters are normal. A long list is not.");
} else {
  console.log("\n(no SUPABASE_URL / SERVICE_ROLE_KEY, skipping the match check)");
}

console.log("\nNOTHING WAS WRITTEN.");
