// backfill-cbk.ts
// One-time (idempotent) loader: CBK historical T-bill auction results →
// rate_history. Years of official history in one pass; upsert on
// (fund_id, as_of) so re-running is safe.
//
// Source: CBK auction results / historical downloads
//   https://www.centralbank.go.ke/securities/treasury-bills/
//
// Input CSV (no header assumptions — pass column indices if yours differ):
//   date,tenor,rate           e.g.  2025-06-27,364,15.80
// tenor is 91 | 182 | 364 (days).
//
// Usage:
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
//     deno run --allow-env --allow-read --allow-net backfill-cbk.ts auctions.csv
//
// Edit TENOR_FUND to match your funds.id values. Those fund rows must already
// exist (rate_history.fund_id is a FK).

import { createClient } from "jsr:@supabase/supabase-js@2";

const TENOR_FUND: Record<string, string> = {
  "91": "cbk-tbill-91",
  "182": "cbk-tbill-182",
  "364": "cbk-tbill-364",
};

const SOURCE = "cbk-backfill";
const SOURCE_URL =
  "https://www.centralbank.go.ke/securities/treasury-bills/";

interface Row {
  fund_id: string;
  rate: number;
  as_of: string;
  source: string;
  source_url: string;
}

function parseCsv(text: string): Row[] {
  const out: Row[] = [];
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  for (const line of lines) {
    const cols = line.split(",").map((c) => c.trim());
    if (cols.length < 3) continue;
    const [date, tenor, rateStr] = cols;
    // skip a header row if present
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    const fund_id = TENOR_FUND[tenor];
    const rate = Number(rateStr);
    if (!fund_id || !Number.isFinite(rate)) continue;
    out.push({ fund_id, rate, as_of: date, source: SOURCE, source_url: SOURCE_URL });
  }
  return out;
}

async function main() {
  const path = Deno.args[0];
  if (!path) {
    console.error("usage: deno run ... backfill-cbk.ts <auctions.csv>");
    Deno.exit(1);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");
    Deno.exit(1);
  }
  const db = createClient(url, key);

  const rows = parseCsv(await Deno.readTextFile(path));
  if (rows.length === 0) {
    console.error("no valid rows parsed — check the CSV format");
    Deno.exit(1);
  }

  // Upsert in chunks; unique (fund_id, as_of) makes this idempotent.
  const CHUNK = 500;
  let written = 0;
  for (let i = 0; i < rows.length; i += CHUNK) {
    const batch = rows.slice(i, i + CHUNK);
    const { error } = await db
      .from("rate_history")
      .upsert(batch, { onConflict: "fund_id,as_of" });
    if (error) throw new Error(`upsert failed: ${error.message}`);
    written += batch.length;
    console.log(`  wrote ${written}/${rows.length}`);
  }

  // Refresh current_rate to each bill's most recent point.
  for (const fund_id of new Set(rows.map((r) => r.fund_id))) {
    const latest = rows
      .filter((r) => r.fund_id === fund_id)
      .sort((a, b) => (a.as_of < b.as_of ? 1 : -1))[0];
    const { error } = await db
      .from("funds")
      .update({ current_rate: latest.rate })
      .eq("id", fund_id);
    if (error) console.warn(`current_rate update failed for ${fund_id}: ${error.message}`);
  }

  console.log(`done: ${written} rate_history rows across ${new Set(rows.map((r) => r.fund_id)).size} bills`);
}

if (import.meta.main) await main();
