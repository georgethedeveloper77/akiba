// CBK Treasury Bills scraper. Official first-party source, but JS-gated —
// so we render it with a headless browser, then read the latest weighted
// average rate per tenor. Runs on a GitHub Actions cron (see workflow).
import { chromium } from "playwright";
import { createClient } from "@supabase/supabase-js";

const URL = "https://www.centralbank.go.ke/bills-bonds/treasury-bills/";
const SOURCE = "ke-cbk-tbills";

// tenor label on the page -> our funds.id. Unmapped tenors are logged, not
// invented: add cbk-tbill-182 / cbk-tbill-364 in the admin to capture them.
const TENORS = [
  { label: "91-DAY",  fund_id: "cbk-tbill-91" },
  { label: "182-DAY", fund_id: null },
  { label: "364-DAY", fund_id: null },
];

const db = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

// today's date in EAT (UTC+3)
const asOf = new Date(Date.now() + 3 * 3_600_000).toISOString().slice(0, 10);

function rateForTenor(text, label) {
  // grab the section after this tenor label, up to the next tenor label
  const start = text.indexOf(label);
  if (start === -1) return null;
  const section = text.slice(start, start + 400);
  // the page shows "... Average Interest Rate: 8.8275%"
  const m = section.match(/Average Interest Rate:?\s*([\d.]+)\s*%/i);
  return m ? parseFloat(m[1]) : null;
}

async function run() {
  const started = new Date().toISOString();
  const errors = [];
  const unmapped = [];
  const points = [];

  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.goto(URL, { waitUntil: "networkidle", timeout: 60_000 });
    await page.waitForFunction(() => document.body.innerText.includes("DAY"), { timeout: 30_000 });
    const text = await page.evaluate(() => document.body.innerText);

    for (const t of TENORS) {
      const rate = rateForTenor(text, t.label);
      if (rate == null) { errors.push(`no rate found for ${t.label}`); continue; }
      if (!(rate > 0 && rate < 30)) { errors.push(`${t.label}: rate ${rate} out of range`); continue; }
      if (!t.fund_id) { unmapped.push(`${t.label}:${rate}`); continue; }
      points.push({ fund_id: t.fund_id, rate, as_of: asOf, source: SOURCE });
    }
  } catch (e) {
    errors.push(String(e?.message ?? e));
  } finally {
    await browser.close();
  }

  if (points.length) {
    await db.from("rate_history").upsert(points, { onConflict: "fund_id,as_of" });
    for (const p of points) {
      await db.from("funds").update({ current_rate: p.rate, status: "live" }).eq("id", p.fund_id);
    }
    // refresh the app snapshot (edge function reads funds -> writes the CDN file)
    try {
      const r = await fetch(`${process.env.SUPABASE_URL}/functions/v1/publish-snapshot`, {
        method: "POST",
        headers: { "x-cron-secret": process.env.CRON_SECRET },
      });
      if (!r.ok) errors.push(`snapshot trigger: HTTP ${r.status}`);
    } catch (e) {
      errors.push(`snapshot trigger: ${e?.message ?? e}`);
    }
  }

  await db.from("scraper_runs").insert({
    source: SOURCE,
    started_at: started,
    finished_at: new Date().toISOString(),
    written: points.length,
    rejected: 0,
    unmapped,
    errors,
    ok: errors.length === 0,
  });

  console.log(JSON.stringify({ source: SOURCE, written: points.length, unmapped, errors }, null, 2));
  if (errors.length) process.exit(1);
}

run();
